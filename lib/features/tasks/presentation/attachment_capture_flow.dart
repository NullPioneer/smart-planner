import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:smart_reminder/core/services/local_media_service.dart';
import 'package:smart_reminder/features/tasks/domain/models/planner_task.dart';

final class PreparedAttachment {
  const PreparedAttachment({
    required this.path,
    required this.name,
    required this.type,
  });

  final String path;
  final String name;
  final TaskAttachmentType type;
}

enum _CaptureReviewAction { retake, addPage, save, cancel }

enum _CaptureSaveMode { individualImages, pdf, word }

Future<List<PreparedAttachment>> captureTaskAttachments(
  BuildContext context,
  LocalMediaService mediaService,
) async {
  final picker = ImagePicker();
  final pages = <XFile>[];
  while (context.mounted) {
    final captured = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (captured == null) return const [];
    if (!context.mounted) return const [];
    final action = await _reviewCapturedPage(
      context,
      captured,
      pageNumber: pages.length + 1,
    );
    if (action == _CaptureReviewAction.retake) continue;
    if (action == _CaptureReviewAction.cancel || action == null) {
      return const [];
    }
    pages.add(captured);
    if (action == _CaptureReviewAction.addPage) continue;
    break;
  }
  if (pages.isEmpty || !context.mounted) return const [];

  return _prepareImageAttachments(context, mediaService, pages);
}

Future<List<PreparedAttachment>> pickGalleryTaskAttachments(
  BuildContext context,
  LocalMediaService mediaService,
) async {
  final pages = await ImagePicker().pickMultiImage(imageQuality: 92);
  if (pages.isEmpty || !context.mounted) return const [];
  return _prepareImageAttachments(context, mediaService, pages);
}

Future<List<PreparedAttachment>> _prepareImageAttachments(
  BuildContext context,
  LocalMediaService mediaService,
  List<XFile> pages,
) async {
  final mode = await showModalBottomSheet<_CaptureSaveMode>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('How should these pages be saved?'),
            subtitle: Text(
              'Keep every photo separately, or combine all pages into one document.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Individual images'),
            subtitle: Text('${pages.length} separate image attachments'),
            onTap: () =>
                Navigator.pop(sheetContext, _CaptureSaveMode.individualImages),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('One PDF document'),
            subtitle: const Text(
              'Choose a folder, then view it inside the app',
            ),
            onTap: () => Navigator.pop(sheetContext, _CaptureSaveMode.pdf),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('One Word document'),
            subtitle: const Text(
              'Choose a folder, then view it inside the app',
            ),
            onTap: () => Navigator.pop(sheetContext, _CaptureSaveMode.word),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (mode == null) return const [];

  if (mode == _CaptureSaveMode.individualImages) {
    final attachments = <PreparedAttachment>[];
    var savedFolderCopies = 0;
    for (var index = 0; index < pages.length; index++) {
      final page = pages[index];
      final path = await mediaService.importFile(page.path);
      final sourceExtension = p.extension(page.name).toLowerCase();
      final extension = sourceExtension.isEmpty
          ? 'jpg'
          : sourceExtension.substring(1);
      final name =
          'Smart_Planner_photo_${DateTime.now().millisecondsSinceEpoch}_${index + 1}.$extension';
      attachments.add(
        PreparedAttachment(
          path: path,
          name: name,
          type: TaskAttachmentType.image,
        ),
      );
      final savedPath = await _saveFolderCopy(
        bytes: await page.readAsBytes(),
        suggestedName: name,
        extension: extension,
        dialogTitle: pages.length == 1
            ? 'Save a copy of this photo'
            : 'Save a copy of photo ${index + 1}',
      );
      if (savedPath != null) savedFolderCopies++;
    }
    if (context.mounted) {
      _showCopyResult(
        context,
        savedFolderCopies: savedFolderCopies,
        total: attachments.length,
      );
    }
    return attachments;
  }

  final isPdf = mode == _CaptureSaveMode.pdf;
  final bytes = isPdf
      ? await CapturedDocumentCodec.createPdf(pages.map((page) => page.path))
      : await CapturedDocumentCodec.createDocx(pages.map((page) => page.path));
  final extension = isPdf ? 'pdf' : 'docx';
  final suggestedName =
      'Smart_Planner_scan_${DateTime.now().millisecondsSinceEpoch}.$extension';
  final localPath = await mediaService.importBytes(bytes, extension: extension);
  final externalPath = await _saveFolderCopy(
    bytes: bytes,
    suggestedName: suggestedName,
    extension: extension,
    dialogTitle: 'Save a folder copy of your document',
  );
  if (context.mounted) {
    _showCopyResult(
      context,
      savedFolderCopies: externalPath == null ? 0 : 1,
      total: 1,
    );
  }
  return [
    PreparedAttachment(
      path: localPath,
      name: externalPath == null ? suggestedName : p.basename(externalPath),
      type: isPdf ? TaskAttachmentType.pdf : TaskAttachmentType.file,
    ),
  ];
}

Future<String?> _saveFolderCopy({
  required Uint8List bytes,
  required String suggestedName,
  required String extension,
  required String dialogTitle,
}) async {
  try {
    final path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
    return path;
  } catch (_) {
    return null;
  }
}

void _showCopyResult(
  BuildContext context, {
  required int savedFolderCopies,
  required int total,
}) {
  final unsavedCopies = total - savedFolderCopies;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        unsavedCopies == 0
            ? total == 1
                  ? 'Saved in your chosen folder and kept in this reminder.'
                  : 'Saved all copies in your chosen folders and kept them in this reminder.'
            : 'Kept in this reminder. $unsavedCopies folder ${unsavedCopies == 1 ? 'copy was' : 'copies were'} not saved.',
      ),
    ),
  );
}

Future<_CaptureReviewAction?> _reviewCapturedPage(
  BuildContext context,
  XFile file, {
  required int pageNumber,
}) => showDialog<_CaptureReviewAction>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => Dialog.fullscreen(
    child: SafeArea(
      child: Column(
        children: [
          ListTile(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () =>
                  Navigator.pop(dialogContext, _CaptureReviewAction.cancel),
            ),
            title: Text('Captured page $pageNumber'),
            subtitle: const Text('Check that the page is clear and readable'),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: InteractiveViewer(
                  minScale: .8,
                  maxScale: 4,
                  child: Image.file(File(file.path), fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(dialogContext, _CaptureReviewAction.retake),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Retake'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    _CaptureReviewAction.addPage,
                  ),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add page'),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pop(dialogContext, _CaptureReviewAction.save),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

abstract final class CapturedDocumentCodec {
  static Future<Uint8List> createPdf(Iterable<String> imagePaths) async {
    final document = pw.Document();
    for (final imagePath in imagePaths) {
      final image = pw.MemoryImage(await File(imagePath).readAsBytes());
      document.addPage(
        pw.Page(
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    return document.save();
  }

  static Future<Uint8List> createDocx(Iterable<String> imagePaths) async {
    final paths = imagePaths.toList();
    final archive = Archive();
    final relationships = StringBuffer();
    final documentBody = StringBuffer(
      '<w:p><w:r><w:t>Smart Planner captured document</w:t></w:r></w:p>',
    );
    for (var index = 0; index < paths.length; index++) {
      final id = index + 1;
      final source = paths[index];
      final sourceExtension = p.extension(source).toLowerCase();
      final extension = sourceExtension == '.png' ? 'png' : 'jpg';
      final mediaName = 'page_$id.$extension';
      archive.addFile(
        ArchiveFile.bytes(
          'word/media/$mediaName',
          await File(source).readAsBytes(),
        ),
      );
      relationships.write(
        '<Relationship Id="rId$id" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
        'Target="media/$mediaName"/>',
      );
      documentBody.write(_docxImageParagraph(id));
      if (index < paths.length - 1) {
        documentBody.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }
    documentBody.write(
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/>'
      '</w:sectPr>',
    );

    archive
      ..addFile(
        ArchiveFile.string(
          '[Content_Types].xml',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
              '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
              '<Default Extension="xml" ContentType="application/xml"/>'
              '<Default Extension="jpg" ContentType="image/jpeg"/>'
              '<Default Extension="png" ContentType="image/png"/>'
              '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
              '</Types>',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          '_rels/.rels',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
              '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
              '</Relationships>',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'word/_rels/document.xml.rels',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
              '$relationships</Relationships>',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'word/document.xml',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
              'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
              'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
              'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
              'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
              '<w:body>$documentBody</w:body></w:document>',
        ),
      );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _docxImageParagraph(int id) =>
      '<w:p><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
      '<wp:extent cx="5486400" cy="7315200"/><wp:docPr id="$id" name="Captured page $id"/>'
      '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="page_$id"/><pic:cNvPicPr/></pic:nvPicPr>'
      '<pic:blipFill><a:blip r:embed="rId$id"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
      '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="5486400" cy="7315200"/></a:xfrm>'
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
      '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>';

  static Future<WordPreviewData> readDocx(String path) async {
    final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final document = archive.findFile('word/document.xml');
    if (document == null) {
      throw const FormatException('This Word document cannot be read.');
    }
    final xml = utf8.decode(document.readBytes() ?? const []);
    final text = RegExp(
      r'<w:t[^>]*>(.*?)</w:t>',
      dotAll: true,
    ).allMatches(xml).map((match) => _decodeXml(match.group(1)!)).join('\n');
    final images = <Uint8List>[];
    for (final entry in archive.files) {
      final extension = p.extension(entry.name).toLowerCase();
      if (entry.isFile &&
          entry.name.startsWith('word/media/') &&
          const {
            '.jpg',
            '.jpeg',
            '.png',
            '.gif',
            '.webp',
          }.contains(extension)) {
        final bytes = entry.readBytes();
        if (bytes != null) images.add(bytes);
      }
    }
    return WordPreviewData(text: text.trim(), images: images);
  }

  static String _decodeXml(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

final class WordPreviewData {
  const WordPreviewData({required this.text, required this.images});

  final String text;
  final List<Uint8List> images;
}
