import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reminder/features/tasks/presentation/attachment_capture_flow.dart';

void main() {
  test('captured images become previewable PDF and Word documents', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smart_planner_document_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}/page.png');
    await image.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );

    final pdf = await CapturedDocumentCodec.createPdf([image.path]);
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');

    final docx = await CapturedDocumentCodec.createDocx([image.path]);
    final docxFile = File('${directory.path}/scan.docx');
    await docxFile.writeAsBytes(docx);
    final preview = await CapturedDocumentCodec.readDocx(docxFile.path);
    expect(preview.text, contains('Smart Planner captured document'));
    expect(preview.images, hasLength(1));
  });
}
