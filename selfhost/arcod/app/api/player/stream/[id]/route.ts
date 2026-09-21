/**
 * GET /api/player/stream/[id]?quality=N — the stream route a self-hosted
 * instance is missing.
 *
 * Why this file exists: the public deployment serves audio from a player route
 * that is NOT in this repo (`app/api/player/stream/` has no source here), so a
 * fork has a catalog but no way to hand out audio. This route fills that hole
 * using the same `getDownloadURL` helper the download routes already use.
 *
 * Response contract (the Bitly app asks for exactly this):
 *   { url, mimeType, quality, trackId }
 *
 * Quality is a Qobuz format id: 5 = MP3 320, 6 = FLAC 16/44.1,
 * 7 = FLAC 24/<=96 kHz, 27 = FLAC above that. `STREAM_GUEST_QUALITY` caps what
 * an anonymous request may ask for (default 27 = no cap). When Supabase is
 * configured and the request carries a valid session, the cap does not apply.
 */

import { NextRequest, NextResponse } from 'next/server';
import { getDownloadURL } from '@/lib/qobuz-dl-server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

/** Qobuz format id → what its CDN sends for that file. */
const MIME_BY_QUALITY = new Map<string, string>([
    ['5', 'audio/mpeg'],
    ['6', 'audio/flac'],
    ['7', 'audio/flac'],
    ['27', 'audio/flac'],
]);

/** Highest quality an anonymous request may ask for (default: no cap). */
function guestLimit(): number {
    const raw = Number(process.env.STREAM_GUEST_QUALITY ?? '27');
    return Number.isFinite(raw) ? raw : 27;
}

/**
 * True when the request carries a Supabase session we can verify against the
 * project configured here. Without SUPABASE_URL/ANON_KEY every request counts
 * as anonymous — a self-hosted instance works without Supabase at all.
 */
async function hasValidSession(request: NextRequest): Promise<boolean> {
    const auth = request.headers.get('Authorization') ?? request.headers.get('authorization') ?? '';
    if (!auth.toLowerCase().startsWith('bearer ')) return false;
    const supabaseUrl = process.env.SUPABASE_URL;
    const anonKey = process.env.SUPABASE_ANON_KEY;
    if (!supabaseUrl || !anonKey) return false;
    try {
        const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
            headers: { apikey: anonKey, Authorization: auth },
            cache: 'no-store',
        });
        return response.ok;
    } catch {
        return false;
    }
}

export async function GET(
    request: NextRequest,
    { params }: { params: Promise<{ id: string }> }
) {
    const { id } = await params;
    const trackId = Number(id);
    if (!Number.isInteger(trackId) || trackId <= 0) {
        return NextResponse.json({ error: 'A numeric track id is required' }, { status: 400 });
    }

    const quality = request.nextUrl.searchParams.get('quality') ?? '6';
    const mimeType = MIME_BY_QUALITY.get(quality);
    if (!mimeType) {
        return NextResponse.json(
            { error: `Unsupported quality "${quality}" (use 5, 6, 7 or 27)` },
            { status: 400 }
        );
    }

    if (!(await hasValidSession(request)) && Number(quality) > guestLimit()) {
        return NextResponse.json(
            { error: 'Authentication required for Hi-Res streaming' },
            { status: 403 }
        );
    }

    try {
        const country = request.headers.get('Token-Country') || undefined;
        const url = await getDownloadURL(
            trackId,
            quality,
            country ? { country } : undefined
        );
        if (typeof url !== 'string' || !/^https?:\/\//.test(url)) {
            return NextResponse.json(
                { error: 'This track has no streamable file (region-restricted?)' },
                { status: 502 }
            );
        }
        return NextResponse.json({ url, mimeType, quality: Number(quality), trackId });
    } catch (error) {
        const reason = String((error as Error)?.message ?? error);
        // An empty token pool is not a per-track failure: the app puts the whole
        // source on a backoff when the message mentions tokens, instead of
        // paying the wait again on every song. Keep that word.
        const outOfTokens = /token/i.test(reason);
        return NextResponse.json(
            {
                error: outOfTokens
                    ? `No healthy Qobuz tokens available (${reason})`
                    : `Failed to get streaming URL: ${reason}`,
            },
            { status: outOfTokens ? 503 : 502 }
        );
    }
}
