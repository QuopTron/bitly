package main

import (
	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

// dispatchExtra handles extensions, YouTube OAuth, signed session, premium,
// playback, similar/rescue, convert/playlist and library methods. Returns
// handled=false for methods outside this domain.
func dispatchExtra(method string, params map[string]interface{}) (interface{}, string, bool) {
	switch method {
	// ── Extensions ──────────────────────────────────────────
	case "initExtensionSystem":
		return backend.InitExtensionSystem(rpcBody(params)), "", true
	case "loadExtensionsFromDir":
		return backend.LoadExtensionsFromDir(rpcBody(params)), "", true
	case "getInstalledExtensions":
		return backend.GetInstalledExtensions(), "", true
	case "getBundledExtensions":
		return backend.GetBundledExtensions(), "", true
	case "setExtensionSettings":
		return backend.SetExtensionSettings(rpcBody(params)), "", true
	case "reinitializeExtension":
		return backend.ReinitializeExtension(rpcBody(params)), "", true
	case "invokeExtensionAction":
		return backend.InvokeExtensionAction(rpcBody(params)), "", true

	// ── YouTube OAuth ───────────────────────────────────────
	case "startYoutubeOauth":
		return backend.StartYoutubeOauth(rpcBody(params)), "", true
	case "pollYoutubeOauth":
		return backend.PollYoutubeOauth(rpcBody(params)), "", true
	case "exchangeYoutubeOauth":
		return backend.ExchangeYoutubeOauth(rpcBody(params)), "", true
	case "refreshYoutubeOauth":
		return backend.RefreshYoutubeOauth(rpcBody(params)), "", true
	case "stopYoutubeOauth":
		return backend.StopYoutubeOauth(rpcBody(params)), "", true

	// ── Signed Session ──────────────────────────────────────
	case "getPendingVerificationUrl":
		return backend.GetPendingVerificationUrl(rpcBody(params)), "", true
	case "triggerExtensionVerification":
		return backend.TriggerExtensionVerification(rpcBody(params)), "", true
	case "completeSignedSessionGrant":
		return backend.CompleteSignedSessionGrant(rpcBody(params)), "", true
	case "getSignedSessionAuthURL":
		return backend.GetSignedSessionAuthURL(rpcGet(params, "extension_id")), "", true
	case "getSignedSessionStatus":
		return backend.GetSignedSessionStatus(rpcGet(params, "extension_id")), "", true
	case "clearSignedSession":
		return backend.ClearSignedSession(rpcGet(params, "extension_id")), "", true
	case "setSignedSessionCallbackUrl":
		return backend.SetSignedSessionCallbackURL(rpcGet(params, "url")), "", true
	case "provisionSignedSessions":
		return backend.ProvisionSignedSessions(rpcBody(params)), "", true
	case "keepAliveSignedSessions":
		return backend.KeepAliveSignedSessions(rpcBody(params)), "", true

	// ── Premium ─────────────────────────────────────────────
	case "getPremiumStatus":
		return backend.GetPremiumStatus(), "", true
	case "validatePremiumCode":
		return backend.ValidatePremiumCode(rpcBody(params)), "", true
	case "setPremiumStatus":
		return backend.SetPremiumStatus(rpcBody(params)), "", true
	case "setPremiumGithubToken":
		return backend.SetPremiumGithubToken(rpcBody(params)), "", true
	case "checkDownloadAllowed":
		return backend.CheckDownloadAllowed(), "", true

	// ── Playback ────────────────────────────────────────────
	case "reportNowPlaying":
		return backend.ReportNowPlaying(rpcBody(params)), "", true
	case "getNowPlaying":
		return backend.GetNowPlaying(), "", true
	case "markPlayed":
		return backend.MarkPlayed(rpcBody(params)), "", true
	case "getPlayHistory":
		return backend.GetPlayHistory(intDe(params, "limit", 20)), "", true
	case "getPlayQueue":
		return backend.GetPlayQueue(), "", true
	case "addToQueue":
		return backend.AddToQueue(rpcBody(params)), "", true
	case "removeFromQueue":
		return backend.RemoveFromQueue(intDe(params, "position", 0)), "", true
	case "clearQueue":
		return backend.ClearQueue(), "", true
	case "getPlaybackStats":
		return backend.GetPlaybackStats(), "", true
	case "getTopTracks":
		return backend.GetTopTracks(intDe(params, "limit", 10)), "", true
	case "getPlayCount":
		return backend.GetPlayCount(rpcGet(params, "track_id")), "", true
	case "getRecommendationsFromHistory":
		return backend.GetRecommendationsFromHistory(intDe(params, "limit", 10)), "", true

	// ── Similar / Recommendations ───────────────────────────
	case "getSimilarTracks":
		return backend.GetSimilarTracks(rpcBody(params)), "", true
	case "getSimilarArtists":
		return backend.GetSimilarArtists(rpcBody(params)), "", true

	// ── Rescue ──────────────────────────────────────────────
	case "rescueTrack":
		return backend.RescueTrack(rpcBody(params)), "", true
	case "rescueBatch":
		return backend.RescueBatch(rpcBody(params)), "", true
	case "enrichMetadata":
		return backend.EnrichMetadata(rpcGet(params, "isrc")), "", true

	// ── Convert / Playlist / CUE ────────────────────────────
	case "convertFile":
		return backend.ConvertFile(rpcBody(params)), "", true
	case "exportPlaylistXSPF":
		return backend.ExportPlaylistXSPF(rpcBody(params)), "", true
	case "parsePlaylistXSPF":
		return backend.ParsePlaylistXSPF(rpcBody(params)), "", true
	case "parseCUE":
		return backend.ParseCUE(rpcBody(params)), "", true
	case "readFileMetadata":
		return backend.ReadFileMetadata(rpcGet(params, "path")), "", true
	case "writeFileMetadata":
		return backend.WriteFileMetadata(rpcBody(params)), "", true
	case "getProviderHealthStatus":
		return backend.GetProviderHealthStatus(), "", true

	// ── Library ─────────────────────────────────────────────
	case "scanLibrary":
		return backend.ScanLibrary(rpcGet(params, "directory")), "", true
	case "getLibraryStats":
		return backend.GetLibraryStats(), "", true

	// ── Scrobble ────────────────────────────────────────────
	case "setupScrobbling":
		return backend.SetupScrobbling(rpcBody(params)), "", true
	case "scrobbleTrack":
		return backend.ScrobbleTrack(rpcBody(params)), "", true
	case "updateNowPlaying":
		return backend.UpdateNowPlaying(rpcBody(params)), "", true

	// ── Reset ───────────────────────────────────────────────
	case "resetDatabase":
		return backend.ResetDatabase(), "", true
	}
	return nil, "", false
}
