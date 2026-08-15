import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ImageGuardService {
  static final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Scans local image for contact information, digits, or social handles.
  /// Returns true if image is clean; false if restricted contact text is found.
  static Future<bool> validateProfilePhoto(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final extractedText = recognizedText.text.replaceAll(RegExp(r'\s+'), '').toLowerCase();

      // Check 1: Continuous or broken phone numbers (6+ digits)
      final hasPhoneNumber = RegExp(r'\d{6,}').hasMatch(extractedText);

      // Check 2: Social media keywords & handle symbols
      final hasSocialHandle = RegExp(r'(insta|ig|telegram|tg|snap|snapchat|wa|whatsapp|fb|call|dm|@)').hasMatch(extractedText);

      // Check 3: Web links or domain extensions
      final hasUrl = RegExp(r'(\.com|\.me|\.in|\.co|\.org|wa\.me|t\.me)').hasMatch(extractedText);

      if (hasPhoneNumber || hasSocialHandle || hasUrl) {
        return false; // Photo rejected due to contact leak
      }

      return true; // Clean photo
    } catch (e) {
      // Fail-safe: allow photo if OCR fails to process
      return true;
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
