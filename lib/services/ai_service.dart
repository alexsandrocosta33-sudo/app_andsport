import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Sua chave de API atualizada que começa com AQ.
  final String _apiKey =
      'AQ.Ab8RN6Johx-1z38kq_Xkqp7W7n6DWIcRzVyZSase85QjWtt_Rg';

  // Método do Copiloto do Professor: Monta o esqueleto do treino baseado na biblioteca
  Future<String> gerarSugestaoTreino({
    required String objetivo,
    required String nivel,
    required List<String> exerciciosDisponiveis,
  }) async {
    if (_apiKey.isEmpty) {
      return "Erro: Chave de API do Gemini não configurada no ai_service.dart.";
    }

    List<String> listaValida = exerciciosDisponiveis.isEmpty
        ? [
            'Supino Reto',
            'Agachamento Livre',
            'Leg Press',
            'Puxada Frente',
            'Rosca Direta',
            'Tríceps Corda',
          ]
        : exerciciosDisponiveis;

    final prompt =
        '''
    Você é um assistente de Inteligência Artificial especialista em musculação e personal trainer do aplicativo Andsport.
    Sua tarefa é ajudar o professor a estruturar uma sugestão de ficha de treino.
    
    Objetivo do Aluno: $objetivo
    Nível do Aluno: $nivel
    Lista de exercícios cadastrados na biblioteca da academia: ${listaValida.join(', ')}
    
    Selecione de 4 a 6 exercícios dessa lista que melhor se encaixam no objetivo e nível informados. 
    Retorne uma resposta curta, direta e formatada em tópicos, dizendo o nome do exercício e sugerindo uma quantidade de séries e repetições (ex: 4x10 ou 3x12) ideal para o caso.
    Seja motivador e direto ao ponto, sem introduções longas.
    ''';

    try {
      // Endpoint estável regional do Google Vertex AI que aceita chaves AQ de forma direta por HTTP
      final url = Uri.parse(
        'https://us-central1-aiplatform.googleapis.com/v1/projects/aplicativo-andsport/locations/us-central1/publishers/google/models/gemini-1.5-flash:generateContent?key=$_apiKey',
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
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['candidates'][0]['content']['parts'][0]['text'] ??
            "Não foi possível gerar uma sugestão.";
      } else {
        return "Erro na API do Google Cloud (${response.statusCode}): ${response.body}";
      }
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

    final prompt =
        '''
    Você é o assistente virtual de treino do aplicativo Andsport.
    O aluno está visualizando o gráfico de evolução do exercício: $nomeExercicio.
    O histórico recente de cargas anotadas por ele, da mais antiga para a mais recente, é: ${historicoCargas.join(' -> ')}.
    
    Analise brevemente esse comportamento:
    1. Se o peso está estagnado (igual) há mais de 3 anotações, sugira de forma motivadora que ele tente subir de 1kg a 2kg para quebrar o platô e gerar novos estímulos.
    2. Se o peso vem subindo, dê os parabéns pelo foco e pela progressão de força.
    3. Se houver apenas 1 ou 2 anotações, dê uma dica geral de execução ou incentive-o a continuar registrando os pesos.
    
    Retorne uma resposta curta (máximo 3 linhas), bem direta, usando emojis de academia e focando na motivação do treino.
    ''';

    try {
      final url = Uri.parse(
        'https://us-central1-aiplatform.googleapis.com/v1/projects/aplicativo-andsport/locations/us-central1/publishers/google/models/gemini-1.5-flash:generateContent?key=$_apiKey',
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
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['candidates'][0]['content']['parts'][0]['text'] ??
            "Continue focado nos treinos!";
      } else {
        return "Grave seus pesos a cada treino para ver sua evolução! 🔥";
      }
    } catch (e) {
      return "Grave seus pesos a cada treino para ver sua evolução! 🔥";
    }
  }
}
