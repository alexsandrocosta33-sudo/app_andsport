import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // ATENÇÃO: Substitua 'SUA_CHAVE_AIZA_AQUI' pela chave que começa com AIza
  // que você copiou do console do Google Cloud (aquela obtida em 7_12.jpg).
  final String _apiKey =
      'AQ.Ab8RN6LdNCvzQEinjHXqhuiBPMs9fyO198x6iHrIawP0glwIEw';

  Future<String> _executarChamadaVertex(String prompt) async {
    // Esta URL utiliza o endpoint do Google Generative Language,
    // que é o formato correto para autenticação via Chave de API (AIza).
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey',
    );

    try {
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
        // O caminho dos dados na resposta da API Generative Language é este:
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return "Erro na API (${response.statusCode}): ${response.body}";
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
