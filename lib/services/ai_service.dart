import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Sua chave AQ. perfeitamente vinculada e ativa
  final String _apiKey =
      'AQ.Ab8RN6LdNCvzQEinjHXqhuiBPMs9fyO198x6iHrlawP0glwIEw';

  Future<String> _executarChamadaVertex(String prompt) async {
    // Como você marcou a "Gemini API" nas restrições da chave,
    // usamos obrigatoriamente esta URL abaixo. Ela aceita o parâmetro ?key= direto.
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
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        // Se houver qualquer detalhe, o erro completo vai aparecer na tela
        return "Erro na resposta da API (${response.statusCode}): ${response.body}";
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
