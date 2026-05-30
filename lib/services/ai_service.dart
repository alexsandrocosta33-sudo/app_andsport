import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Sua chave estável e vinculada do console
  final String _apiKey =
      'AQ.Ab8RN6LdNCvzQEinjHXqhuiBPMs9fyO198x6iHrlawP0glwIEw';

  // ID numérico do seu projeto onde a Vertex AI e a conta de serviço estão operando
  final String _projectIdNum = '1054648561946';

  Future<String> _executarChamadaVertex(String prompt) async {
    // Rota da Vertex AI (us-central1), que é o escopo nativo da sua chave AQ.
    final url = Uri.parse(
      'https://us-central1-aiplatform.googleapis.com/v1/projects/$_projectIdNum/locations/us-central1/publishers/google/models/gemini-1.5-flash:generateContent',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Passamos a chave vinculada no cabeçalho de autorização de API do Google
          'Authorization': 'Bearer $_apiKey',
        },
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
        // Se houver recusa, o corpo completo do erro vai aparecer direto na caixa de texto do App
        return "Erro de escopo Vertex (${response.statusCode}): ${response.body}";
      }
    } catch (e) {
      return "Erro de conexão: $e";
    }
  }

  Future<String> gerarSugestaoTreino({
    required String objetivo,
    required String nivel,
    required List<String> exerciciosDisponiveis,
  }) async {
    return _executarChamadaVertex(
      'Crie um treino estruturado para o objetivo "$objetivo", nível "$nivel". Use apenas estes exercícios: ${exerciciosDisponiveis.join(', ')}.',
    );
  }

  Future<String> analisarProgressaoCarga({
    required String nomeExercicio,
    required List<String> historicoCargas,
  }) async {
    return _executarChamadaVertex(
      'Analise a progressão de carga do exercício "$nomeExercicio". Histórico: ${historicoCargas.join(' -> ')}. Dê um feedback curto e motivador.',
    );
  }
}
