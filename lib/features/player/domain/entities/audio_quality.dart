enum AudioQuality {
  mp3_128('MP3 128kbps', 128),
  mp3_320('MP3 320kbps', 320),
  flac_16('FLAC 16-bit', 1411),
  flac_24('FLAC 24-bit', 2304);

  final String label;
  final int bitrate;
  const AudioQuality(this.label, this.bitrate);
}
