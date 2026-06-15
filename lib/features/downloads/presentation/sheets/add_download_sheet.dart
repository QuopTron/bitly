import 'package:flutter/material.dart';
import '../../data/models/download_item_model.dart';
import '../../data/models/queue_item_model.dart';

class AddDownloadSheet extends StatefulWidget {
  const AddDownloadSheet({super.key});

  @override
  State<AddDownloadSheet> createState() => _AddDownloadSheetState();
}

class _AddDownloadSheetState extends State<AddDownloadSheet> {
  final _urlController = TextEditingController();
  String _selectedQuality = '320';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final now = DateTime.now();
    final item = DownloadItemModel(
      id: now.millisecondsSinceEpoch.toString(),
      title: url.split('/').last,
      artist: 'Unknown',
      url: url,
      quality: _selectedQuality,
      addedAt: now,
    );
    final queueItem = QueueItemModel(
      id: 'q_${item.id}',
      downloadItemId: item.id,
      addedAt: now,
    );

    Navigator.pop(context, {'item': item, 'queueItem': queueItem});
  }

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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Add Download',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Paste download URL...',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF282828),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.link,
                  color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Quality:',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                value: _selectedQuality,
                dropdownColor: const Color(0xFF282828),
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.arrow_drop_down,
                    color: Color(0xFF1DB954)),
                items: const [
                  DropdownMenuItem(
                      value: '128', child: Text('128 kbps')),
                  DropdownMenuItem(
                      value: '320', child: Text('320 kbps')),
                  DropdownMenuItem(
                      value: 'flac', child: Text('FLAC')),
                ],
                onChanged: (v) =>
                    setState(() => _selectedQuality = v!),
              ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add to Queue',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
