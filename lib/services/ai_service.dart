import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  // Sua chave AQ. funciona perfeitamente com o SDK oficial
  final String _apiKey =
      'AQ.Ab8RN6KkUsADyS4S_SOqo3-bw7iuxsrnqiHnrza6QSvFh18X8Q';

  Future<String> gerarSugestaoTreino({
    required String objetivo,
    required String nivel,
    required List<String> exerciciosDisponiveis,
  }) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);

      final prompt =
          '''
      Você é um assistente especialista em musculação do aplicativo Andsport.
      Objetivo: $objetivo, Nível: $nivel.
      Exercícios disponíveis: ${exerciciosDisponiveis.join(', ')}.
      Selecione 4-6 exercícios, retorne curto, em tópicos, com séries/repetições.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Não consegui gerar o treino.";
    } catch (e) {
      return "Erro: $e";
    }
  }

  Future<String> analisarProgressaoCarga({
    required String nomeExercicio,
    required List<String> historicoCargas,
  }) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);

      final prompt =
          'Analise a progressão do exercício $nomeExercicio: ${historicoCargas.join(' -> ')}. Dê uma dica motivacional curta.';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Continue focado! 🔥";
    } catch (e) {
      return "Continue focado nos treinos! 🔥";
    }
  }
}
