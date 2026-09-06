// Package drm implements progressive (range-addressable) decryption of the
// DRM/encrypted audio formats the download pipeline produces, so playback can
// start while the encrypted file is still being downloaded.
//
// Two schemes are supported (see DRM_PROGRESIVO_DESIGN.md):
//
//   - deezer Blowfish: every THIRD full 2048-byte block is Blowfish-CBC
//     encrypted with the per-track key (md5-hex ASCII XOR secret) and the fixed
//     IV 0001020304050607. Each block is independent, so any byte range is
//     decryptable by processing only the 2048-byte blocks it touches.
//   - amazon mov_key (AES-128-CTR, ISO-BMFF): to be added once Fase 0 golden
//     fixtures confirm the exact ffmpeg decryption_key IV/CTR construction.
//
// Fase 0 state: golden fixtures for the deezer scheme live in testdata/;
// real amazon mov_key fixtures require a verified signed session.
package drm
