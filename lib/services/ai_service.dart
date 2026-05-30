import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Sua chave AQ. conforme print 7_10.jpg
  final String _apiKey =
      'AQ.Ab8RN6KkUsADyS4S_SOqo3-bw7iuxsrnqiHnrza6QSvFh18X8Q';

  // ID do projeto conforme print 7_10.jpg
  final String _projectId = '1054648561946';

  Future<String> _executarChamadaVertex(String prompt) async {
    // URL seguindo a estrutura do GCP para Vertex AI
    final url = Uri.parse(
      'https://us-central1-aiplatform.googleapis.com/v1/projects/$_projectId/locations/us-central1/publishers/google/models/gemini-1.5-flash:generateContent?key=$_apiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      return "Erro na API do Vertex (${response.statusCode}): ${response.body}";
    }
  }

  Future<String> gerarSugestaoTreino({
    required String objetivo,
    required String nivel,
    required List<String> exerciciosDisponiveis,
  }) async {
    return _executarChamadaVertex(
      'Crie um treino para objetivo $objetivo, nível $nivel com: ${exerciciosDisponiveis.join(', ')}',
    );
  }

  Future<String> analisarProgressaoCarga({
    required String nomeExercicio,
    required List<String> historicoCargas,
  }) async {
    return _executarChamadaVertex(
      'Analise a progressão do $nomeExercicio: ${historicoCargas.join(' -> ')}',
    );
  }
}
