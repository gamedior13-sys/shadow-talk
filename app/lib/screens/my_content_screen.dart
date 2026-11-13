import 'package:flutter/material.dart';

/// Màn "Nội dung của tôi" — phần thân đầy đủ làm ở bước 6
/// (dán text → tự tách câu + TTS; nhập file audio + transcript).
class MyContentScreen extends StatelessWidget {
  const MyContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('Nội dung của tôi')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dán đoạn tiếng Anh muốn luyện:',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Hello, how are you? My name is Phong...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: null, // bước 6 sẽ kích hoạt
                    child: const Text('Tạo bài luyện (sắp có)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: null, // bước 6 sẽ kích hoạt
                    child: const Text('Nhập file audio'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Bước 6 sẽ tự tách câu, đọc bằng giọng máy và lưu thành bài luyện.',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
