import 'package:syncfusion_flutter_pdf/pdf.dart';

class DocumentParser {
  static Future<String> extractTextFromPdf(List<int> bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      return 'Error extracting text: $e';
    }
  }
}
