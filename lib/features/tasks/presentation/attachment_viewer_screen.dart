import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';
import 'package:smart_reminder/features/tasks/presentation/attachment_capture_flow.dart';

class AttachmentViewerScreen extends StatelessWidget {
  const AttachmentViewerScreen({required this.attachment, super.key});

  final TaskAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final file = File(attachment.path);
    final extension = p.extension(attachment.displayName).toLowerCase();
    return Scaffold(
      appBar: AppBar(title: Text(attachment.displayName)),
      body: !file.existsSync()
          ? const _ViewerMessage(
              icon: Icons.file_present_outlined,
              message: 'This attachment is missing from local storage.',
            )
          : attachment.type == TaskAttachmentType.image
          ? ColoredBox(
              color: Colors.black,
              child: Center(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 6,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
            )
          : extension == '.pdf'
          ? PdfPreview(
              build: (_) => file.readAsBytes(),
              allowPrinting: false,
              allowSharing: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              useActions: false,
              pdfFileName: attachment.displayName,
            )
          : extension == '.docx'
          ? _WordDocumentPreview(path: attachment.path)
          : const _ViewerMessage(
              icon: Icons.description_outlined,
              message:
                  'This file format has no in-app preview. Word documents should use the .docx format.',
            ),
    );
  }
}

class _WordDocumentPreview extends StatelessWidget {
  const _WordDocumentPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => FutureBuilder<WordPreviewData>(
    future: CapturedDocumentCodec.readDocx(path),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return const _ViewerMessage(
          icon: Icons.error_outline_rounded,
          message: 'This Word document could not be displayed.',
        );
      }
      final document = snapshot.data!;
      if (document.text.isEmpty && document.images.isEmpty) {
        return const _ViewerMessage(
          icon: Icons.description_outlined,
          message: 'This Word document does not contain previewable content.',
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        children: [
          if (document.text.isNotEmpty)
            SelectableText(
              document.text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (document.text.isNotEmpty && document.images.isNotEmpty)
            const SizedBox(height: 18),
          for (var index = 0; index < document.images.length; index++) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(document.images[index], fit: BoxFit.contain),
            ),
            if (index < document.images.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    },
  );
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    ),
  );
}
