import 'package:flutter/material.dart';

/// Classifies a track's audio quality into a visual tier.
({
  Color color,
  Color containerColor,
  IconData icon,
  String label,
  String shortLabel,
}) classifyQuality(String? audioQuality, String? codec) {
  final q = (audioQuality ?? '').toLowerCase();
  final c = (codec ?? '').toLowerCase();

  final isMqa = q.contains('mqa');
  final isDsd = q.contains('dsd');
  final isHiRes24 = q.contains('24');
  final isHiRes96 = q.contains('96') || q.contains('192');
  final isFlac = c.contains('flac');
  final isAlac = c.contains('alac');
  final isLossless = q.contains('lossless') || q.contains('16');
  final isHigh = q.contains('320') || q.contains('aac') || q.contains('256') || q.contains('ogg');
  final isMp3 = q.contains('mp3') || q.contains('128');

  if (isMqa) {
    return (
      color: const Color(0xFFE040FB),
      containerColor: const Color(0xFFE040FB),
      icon: Icons.verified_rounded,
      label: 'MQA',
      shortLabel: 'MQA',
    );
  }
  if (isDsd || isHiRes24 || isHiRes96) {
    return (
      color: const Color(0xFF7C4DFF),
      containerColor: const Color(0xFF7C4DFF),
      icon: Icons.four_k_rounded,
      label: 'HI-RES',
      shortLabel: 'HR',
    );
  }
  if (isFlac || isAlac || isLossless) {
    return (
      color: const Color(0xFF00BFA5),
      containerColor: const Color(0xFF00BFA5),
      icon: Icons.music_note_rounded,
      label: 'LOSSLESS',
      shortLabel: 'LL',
    );
  }
  if (isHigh) {
    return (
      color: const Color(0xFFFF6D00),
      containerColor: const Color(0xFFFF6D00),
      icon: Icons.audiotrack_rounded,
      label: 'HIGH',
      shortLabel: 'HQ',
    );
  }
  if (isMp3) {
    return (
      color: const Color(0xFF448AFF),
      containerColor: const Color(0xFF448AFF),
      icon: Icons.graphic_eq_rounded,
      label: 'MP3',
      shortLabel: 'MP3',
    );
  }
  return (
    color: const Color(0xFF78909C),
    containerColor: const Color(0xFF78909C),
    icon: Icons.graphic_eq_rounded,
    label: 'AUDIO',
    shortLabel: 'AU',
  );
}

class AudioQualityBadge extends StatelessWidget {
  final String label;
  final String? codec;
  final ColorScheme colorScheme;

  const AudioQualityBadge({
    super.key,
    required this.label,
    this.codec,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final tier = classifyQuality(label, codec);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: tier.color.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: 10, color: tier.color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: tier.color,
              height: 1.3,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class AudioCodecBadge extends StatelessWidget {
  final String codec;
  final ColorScheme colorScheme;

  const AudioCodecBadge({
    super.key,
    required this.codec,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final c = codec.toLowerCase();
    Color codecColor;
    IconData codecIcon;
    if (c.contains('flac')) {
      codecColor = const Color(0xFF00BFA5);
      codecIcon = Icons.compress_rounded;
    } else if (c.contains('alac')) {
      codecColor = const Color(0xFF00BFA5);
      codecIcon = Icons.compress_rounded;
    } else if (c.contains('aac')) {
      codecColor = const Color(0xFFFF6D00);
      codecIcon = Icons.audiotrack_rounded;
    } else if (c.contains('mp3')) {
      codecColor = const Color(0xFF448AFF);
      codecIcon = Icons.audiotrack_rounded;
    } else if (c.contains('ogg') || c.contains('vorbis')) {
      codecColor = const Color(0xFFFF6D00);
      codecIcon = Icons.audiotrack_rounded;
    } else {
      codecColor = colorScheme.onSurfaceVariant;
      codecIcon = Icons.insert_drive_file_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: codecColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: codecColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(codecIcon, size: 9, color: codecColor),
          const SizedBox(width: 2),
          Text(
            codec.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: codecColor,
              height: 1.3,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class DolbyAtmosBadge extends StatelessWidget {
  final ColorScheme colorScheme;

  const DolbyAtmosBadge({super.key, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(14, 10),
            painter: DolbyLogoPainter(color: colorScheme.onTertiaryContainer),
          ),
          const SizedBox(width: 3),
          Text(
            'Atmos',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: colorScheme.onTertiaryContainer,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class DolbyLogoPainter extends CustomPainter {
  final Color color;

  DolbyLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final h = size.height;
    final w = size.width;
    final cy = h / 2;

    final leftPath = Path()
      ..moveTo(w * 0.08, 0)
      ..lineTo(w * 0.08, h)
      ..lineTo(w * 0.20, h)
      ..arcToPoint(
        Offset(w * 0.20, 0),
        radius: Radius.elliptical(w * 0.25, cy),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(leftPath, paint);

    final rightPath = Path()
      ..moveTo(w * 0.92, 0)
      ..lineTo(w * 0.92, h)
      ..lineTo(w * 0.80, h)
      ..arcToPoint(
        Offset(w * 0.80, 0),
        radius: Radius.elliptical(w * 0.25, cy),
        clockwise: true,
      )
      ..close();
    canvas.drawPath(rightPath, paint);
  }

  @override
  bool shouldRepaint(DolbyLogoPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Convenience builder: returns a list of quality badge widgets for a track.
/// Pass the result into a Row using spread operator.
List<Widget> buildQualityBadges({
  required String? audioQuality,
  required String? audioModes,
  required ColorScheme colorScheme,
  String? codec,
}) {
  final badges = <Widget>[];

  if (audioQuality != null && audioQuality.isNotEmpty) {
    badges.add(
      AudioQualityBadge(
        label: audioQuality,
        codec: codec,
        colorScheme: colorScheme,
      ),
    );
  }

  if (codec != null && codec.isNotEmpty) {
    if (badges.isNotEmpty) badges.add(const SizedBox(width: 3));
    badges.add(
      AudioCodecBadge(codec: codec, colorScheme: colorScheme),
    );
  }

  if (audioModes != null && audioModes.contains('DOLBY_ATMOS')) {
    if (badges.isNotEmpty) badges.add(const SizedBox(width: 3));
    badges.add(DolbyAtmosBadge(colorScheme: colorScheme));
  }

  return badges;
}
