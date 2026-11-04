import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/models/chat_models.dart';

void main() {
  test('parses document metadata on a chat message', () {
    final message = ChatMessageModel.fromJson({
      'id': 'm1',
      'channelId': 'c1',
      'senderId': 'u1',
      'content': '',
      'fileUrl': '/uploads/chat/report.pdf',
      'fileName': 'report.pdf',
      'fileMimeType': 'application/pdf',
      'createdAt': '2026-11-02T10:00:00Z',
    });

    expect(message.hasFile, isTrue);
    expect(message.fileName, 'report.pdf');
    expect(message.fileMimeType, 'application/pdf');
  });
}
