import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AIService {
  // NOTA: Se a sua chave atual (que começa por "AQ.") continuar a dar erro 429 ou 401 nos logs,
  // substitua-a aqui por uma nova chave gerada no Google AI Studio (que começará por "AIzaSy").
  final String _apiKey =
      'AQ.Ab8RN6LHBVV5EQ5P2q6fiuYFa7e3iHH80Qlb-QUyAe3DEw9yzQ';

  Future<String> _executarChamadaGemini(
    String prompt, {
    bool forcarJson = false,
    Uint8List? bytesImagem,
  }) async {
    // Mantemos o endpoint atualizado do modelo flash 2.5 que você já configurou
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
    );

    // Estrutura base da requisição de conteúdo da API do Gemini
    List<Map<String, dynamic>> partsList = [];

    // Se houver uma imagem em bytes recebida, injetamos no payload no padrão inlineData
    if (bytesImagem != null) {
      partsList.add({
        'inlineData': {
          'mimeType': 'image/jpeg',
          'data': base64Encode(bytesImagem),
        },
      });
    }

    // Inserimos o texto do prompt
    partsList.add({'text': prompt});

    Map<String, dynamic> requestBody = {
      'contents': [
        {'parts': partsList},
      ],
    };

    if (forcarJson) {
      requestBody['generationConfig'] = {
        'responseMimeType': 'application/json',
      };
    }

    try {
      // Pequeno delay de segurança para evitar rajadas de requisições acidentais
      await Future.delayed(const Duration(milliseconds: 500));

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      // DIAGNÓSTICO: Expõe a resposta real do servidor da Google no terminal do VS Code caso não seja sucesso
      if (response.statusCode != 200) {
        print("======== DIAGNÓSTICO DE ERRO GEMINI ========");
        print("STATUS CODE: ${response.statusCode}");
        print("RESPONSE BODY: ${response.body}");
        print("============================================");
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      }

      if (response.statusCode == 429) {
        return "ERRO_429: Limite de requisições excedido ou chave de API inválida. Verifique o terminal do VS Code para ver o relatório completo do erro.";
      }

      return "ERRO_STATUS_${response.statusCode}";
    } catch (e) {
      print("LOG_EXCEPCAO_CONEXAO: $e");
      return "ERRO_CONEXAO";
    }
  }

  // CORRIGIDO: Nome alinhado perfeitamente com a chamada da linha 1114 da HomeScreen
  Future<String> gerarSugestaoTreino({
    required String objetivo,
    required String nivel,
    required List<String> exerciciosDisponiveis,
  }) async {
    String prompt =
        'Crie um planejamento de treino estruturado para o objetivo de $objetivo, nível $nivel, utilizando exclusivamente os exercícios fornecidos na sua lista: ${exerciciosDisponiveis.join(', ')}.';
    return _executarChamadaGemini(prompt, forcarJson: false);
  }

  // Mantido para a leitura de evolução da HomeScreen (linha 1399)
  Future<String> analisarProgressaoCarga({
    required String nomeExercicio,
    required List<String> historicoCargas,
  }) async {
    String prompt =
        'Analise a progressão de carga do exercício "$nomeExercicio". Histórico de cargas: ${historicoCargas.join(' -> ')}. Dê um feedback curto, profissional e motivador.';
    return _executarChamadaGemini(prompt, forcarJson: false);
  }

  // NOVA FUNÇÃO: Integração multimodal HTTP com o Scanner de Pratos da HomeScreen
  Future<Map<String, dynamic>> analisarRefeicaoPorFoto(
    Uint8List bytesImagem,
  ) async {
    const prompt =
        "Analise a imagem desta refeição. Identifique os alimentos presentes, estime as porções visíveis e calcule o total aproximado de calorias (kcal) e proteínas (g). "
        "Você DEVE responder estritamente em formato JSON válido, sem qualquer tipo de bloco de formatação ou markdown, contendo as seguintes chaves exatas: "
        "'descricao': (um texto resumido do prato, ex: 'Arroz branco, feijão carioca e filé de frango grelhado'), "
        "'calorias': (apenas o número inteiro de kcal, ex: 520), "
        "'proteinas': (apenas o número inteiro de gramas de proteína, ex: 42).";

    try {
      String respostaPura = await _executarChamadaGemini(
        prompt,
        forcarJson: true,
        bytesImagem: bytesImagem,
      );

      String jsonLimpo = respostaPura
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      return jsonDecode(jsonLimpo);
    } catch (e) {
      print("Erro na análise multimodal da imagem no AIService: $e");
      return {
        'descricao': 'Falha ao processar alimentos na imagem.',
        'calorias': 0,
        'proteinas': 0,
      };
    }
  }

  Future<Map<String, dynamic>> gerarTreinoEmJson({
    required String objetivo,
    required String nivel,
    required List<String> exerciciosDisponiveis,
  }) async {
    String promptContrato =
        '''
    Você é um Personal Trainer experiente. Monte uma estrutura completa de treino focado em "$objetivo" para o nível de experiência "$nivel".
    Use exclusivamente estes exercícios: ${exerciciosDisponiveis.join(', ')}. Não invente exercícios fora desta lista.

    Retorne OBRIGATORIAMENTE um objeto JSON válido seguindo estritamente esta estrutura de chaves:
    {
      "treinos": [
        {
          "nome": "Treino A",
          "exercicios": [
            {"nome": "Nome do Exercício", "series": 4, "repeticoes": 12, "descanso": "60s"}
          ]
        }
      ]
    }
    ''';

    String respostaPura = await _executarChamadaGemini(
      promptContrato,
      forcarJson: true,
    );

    if (respostaPura.startsWith("ERRO_429")) {
      throw Exception(
        "A API do Gemini barrou a requisição (Erro 429). Veja o RESPONSE BODY detalhado impresso no terminal do seu VS Code.",
      );
    }

    if (respostaPura == "ERRO_CONEXAO" ||
        respostaPura.startsWith("ERRO_STATUS_")) {
      throw Exception(
        "O serviço de IA retornou uma inconsistência: $respostaPura",
      );
    }

    String jsonLimpo = respostaPura
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    try {
      return jsonDecode(jsonLimpo);
    } catch (e) {
      throw Exception("Falha ao decodificar a estrutura de treinos.");
    }
  }
}
