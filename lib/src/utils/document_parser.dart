
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class DocumentParser {
  static Future<String> extractTextFromPdf(String filePath) async {
    try {
      final File file = File(filePath);
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      return 'Error extracting text: $e';
    }
  }
}
