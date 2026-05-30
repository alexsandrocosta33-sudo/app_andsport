import 'package:cloud_functions/cloud_functions.dart';

class AIService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<String> _executarChamadaVertex(String prompt) async {
    try {
      // Aciona a função que criamos no passo 1 lá no servidor do Firebase
      HttpsCallable callable = _functions.httpsCallable('gerarConteudoGemini');

      final results = await callable.call(<String, dynamic>{'prompt': prompt});

      // Retorna o texto vindo da IA para a tela do app
      return results.data['text'] as String;
    } catch (e) {
      return "Erro ao processar requisição segura: $e";
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
