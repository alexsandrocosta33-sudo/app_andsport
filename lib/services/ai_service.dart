import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  // Sua chave AQ. definitiva obtida no console
  final String _apiKey =
      'AQ.Ab8RN6LdNCvzQEinjHXqhuiBPMs9fyO198x6iHrlawP0glwIEw';

  // Instancia o modelo oficial usando o SDK do Google
  GenerativeModel _obterModelo() {
    return GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
  }

  Future<String> _executarChamadaVertex(String prompt) async {
    try {
      final model = _obterModelo();
      final content = [Content.text(prompt)];

      // O próprio SDK se encarrega de empacotar a chave AQ. no formato aceito pelo Google
      final response = await model.generateContent(content);

      if (response.text != null) {
        return response.text!;
      } else {
        return "A IA não retornou nenhuma resposta para este prompt.";
      }
    } catch (e) {
      // Caso o Google Cloud aponte alguma falta de permissão interna, o erro sairá limpo aqui
      return "Erro na execução do Gemini: $e";
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
