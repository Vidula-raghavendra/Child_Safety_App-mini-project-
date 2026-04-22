import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
  }

  Future<String> analyzeSafetyReport(String description) async {
    try {
      final content = [Content.text('Analyze this safety report: "$description". Provide a brief risk level assessment (Low, Medium, High) and any immediate advice.')];
      final response = await _model.generateContent(content);
      return response.text ?? "Report received.";
    } catch (e) {
      return "Error reaching AI advisor: $e";
    }
  }
}
