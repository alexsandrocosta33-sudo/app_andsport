import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  // Sua chave de API do Google AI Studio mantida com segurança
  final String _apiKey =
      'AQ.Ab8RN6LsjbSQBAqqfqvWxWZhGgMAdWOrRFQ8BEFvoFVwHCkPBA';

  // Método do Copiloto do Professor: Monta o esqueleto do treino baseado na biblioteca
  Future<String> gerarSugestaoTreino({
    required String objetivo,
    required String nivel,
    required List<String> exerciciosDisponiveis,
  }) async {
    if (_apiKey.isEmpty) {
      return "Erro: Chave de API do Gemini não configurada no ai_service.dart.";
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        requestOptions: const RequestOptions(
          apiVersion: 'v1',
        ), // Forma correta aceita pelo pacote
      );

      final prompt =
          '''
      Você é um assistente de Inteligência Artificial especialista em musculação e personal trainer do aplicativo Andsport.
      Sua tarefa é ajudar o professor a estruturar uma sugestão de ficha de treino.
      
      Objetivo do Aluno: $objetivo
      Nível do Aluno: $nivel
      Lista de exercícios cadastrados na biblioteca da academia: ${exerciciosDisponiveis.join(', ')}
      
      Selecione de 4 a 6 exercícios dessa lista que melhor se encaixam no objetivo e nível informados. 
      Retorne uma resposta curta, direta e formatada em tópicos, dizendo o nome do exercício e sugerindo uma quantidade de séries e repetições (ex: 4x10 ou 3x12) ideal para o caso.
      Seja motivador e direto ao ponto, sem introduções longas.
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? "Não foi possível gerar uma sugestão no momento.";
    } catch (e) {
      return "Erro ao conectar com a IA: $e";
    }
  }

  // Método da Sugestão Inteligente do Aluno: Analisa a progressão de carga
  Future<String> analisarProgressaoCarga({
    required String nomeExercicio,
    required List<String> historicoCargas,
  }) async {
    if (_apiKey.isEmpty) {
      return "Chave de API não configurada.";
    }

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);

      final prompt =
          '''
      Você é o assistente virtual de treino do aplicativo Andsport.
      O aluno está visualizando o gráfico de evolução do exercício: $nomeExercicio.
      O histórico recente de cargas anotadas por ele, da mais antiga para a mais recente, é: ${historicoCargas.join(' -> ')}.
      
      Analise brevemente esse comportamento:
      1. Se o peso está estagnado (igual) há mais de 3 anotações, sugira de forma motivadora que ele tente subir de 1kg a 2kg para quebrar o platô e gerar novos estímulos.
      2. Se o peso vem subindo, dê os parabêns pelo foco e pela progressão de força.
      3. Se houver apenas 1 ou 2 anotações, dê uma dica geral de execução ou incentive-o a continuar registrando os pesos.
      
      Retorne uma resposta curta (máximo 3 linhas), bem direta, usando emojis de academia e focando na motivação do treino.
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ??
          "Continue focado nos treinos e registrando suas cargas! 💪";
    } catch (e) {
      return "Grave seus pesos a cada treino para ver sua evolução! 🔥";
    }
  }
}
