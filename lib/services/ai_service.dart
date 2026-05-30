import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Sua chave AQ. definitiva obtida no console
  final String _apiKey =
      'AQ.Ab8RN6LdNCvzQEinjHXqhuiBPMs9fyO198x6iHrlawP0glwIEw';

  // ID numérico do seu projeto Google Cloud (1054648561946)
  final String _projectIdNum = '1054648561946';

  Future<String> _executarChamadaVertex(String prompt) async {
    // Rota híbrida da Vertex AI que aceita chaves corporativas vinculadas via cabeçalho customizado
    final url = Uri.parse(
      'https://us-central1-aiplatform.googleapis.com/v1/projects/$_projectIdNum/locations/us-central1/publishers/google/models/gemini-1.5-flash:generateContent',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // O SEGREDO: Usamos o cabeçalho específico do Google que valida chaves do tipo AQ.
          // sem disparar o bloqueio de falta de token OAuth2
          'x-goog-api-key': _apiKey,
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
          // Configuração de segurança padrão recomendada para chamadas diretas
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1024},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        // Se houver qualquer detalhe, o erro completo vai aparecer na tela para sabermos o próximo passo
        return "Erro de Resposta (${response.statusCode}): ${response.body}";
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
