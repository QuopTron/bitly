import 'package:flutter/material.dart';
import '../widgets/quality_selector.dart';

class DownloadOptionsSheet extends StatefulWidget {
  final String? trackTitle;

  const DownloadOptionsSheet({super.key, this.trackTitle});

  @override
  State<DownloadOptionsSheet> createState() =>
      _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends State<DownloadOptionsSheet> {
  String _quality = '320';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
              widget.trackTitle != null
                  ? 'Download: ${widget.trackTitle}'
                  : 'Download Options',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Select Quality',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          QualitySelector(
            selectedQuality: _quality,
            onChanged: (v) =>
                setState(() => _quality = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pop(context, _quality),
              icon: const Icon(Icons.download,
                  color: Colors.white),
              label: const Text('Download',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
