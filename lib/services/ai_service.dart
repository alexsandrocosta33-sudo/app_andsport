import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AIService {
  // Chave lida em tempo de compilação via --dart-define=GEMINI_API_KEY=<chave>
  // Nunca coloque a chave diretamente no código-fonte.
  // Para desenvolvimento local: flutter run --dart-define=GEMINI_API_KEY=SUA_CHAVE
  // Para produção (Codemagic): configure GEMINI_API_KEY nas variáveis de ambiente do build.
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<String> _executarChamadaGemini(
    String prompt, {
    bool forcarJson = false,
    Uint8List? bytesImagem,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
    );

    List<Map<String, dynamic>> partsList = [];

    if (bytesImagem != null) {
      partsList.add({
        'inlineData': {
          'mimeType': 'image/jpeg',
          'data': base64Encode(bytesImagem),
        },
      });
    }

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
      await Future.delayed(const Duration(milliseconds: 500));

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        debugPrint("======== DIAGNÓSTICO DE ERRO GEMINI ========");
        debugPrint("STATUS CODE: ${response.statusCode}");
        debugPrint("RESPONSE BODY: ${response.body}");
        debugPrint("============================================");
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final candidates = data['candidates'];
        if (candidates == null || candidates.isEmpty) {
          return "ERRO_SEM_CANDIDATES";
        }

        final content = candidates[0]['content'];
        final parts = content?['parts'];

        if (parts == null || parts.isEmpty || parts[0]['text'] == null) {
          return "ERRO_RESPOSTA_VAZIA";
        }

        return parts[0]['text'].toString();
      }

      if (response.statusCode == 429) {
        final body = jsonDecode(response.body);
        final reason = body['error']?['status']?.toString() ?? '';
        if (reason == 'RESOURCE_EXHAUSTED' || reason.contains('EXHAUSTED')) {
          return "ERRO_429: Serviço de IA temporariamente indisponível por limite de uso. Verifique os créditos da API ou tente novamente mais tarde.";
        }
        return "ERRO_429: Limite de requisições atingido. Tente novamente em alguns minutos.";
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        return "ERRO_AUTH: Chave de API inválida, sem permissão ou bloqueada.";
      }

      return "ERRO_STATUS_${response.statusCode}";
    } catch (e) {
      debugPrint("[AIService] Exceção de conexão: $e");
      return "ERRO_CONEXAO";
    }
  }

  String _limparJson(String resposta) {
    return resposta.replaceAll('```json', '').replaceAll('```', '').trim();
  }

  double _converterNumero(dynamic valor) {
    if (valor == null) return 0.0;

    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;

    return double.tryParse(valor.toString().replaceAll(',', '.').trim()) ?? 0.0;
  }

  Future<String> gerarSugestaoTreino({
    required String objetivo,
    required String nivel,
    required List<String> exerciciosDisponiveis,
  }) async {
    String prompt =
        '''
Crie um planejamento de treino estruturado para o objetivo de $objetivo, nível $nivel.

Use exclusivamente os exercícios fornecidos nesta lista:
${exerciciosDisponiveis.join(', ')}

Responda em português, de forma organizada, profissional e pronta para o professor revisar.
''';

    return _executarChamadaGemini(prompt, forcarJson: false);
  }

  Future<String> analisarProgressaoCarga({
    required String nomeExercicio,
    required List<String> historicoCargas,
  }) async {
    String prompt =
        '''
Analise a progressão de carga do exercício "$nomeExercicio".

Histórico de cargas:
${historicoCargas.join(' -> ')}

Dê um feedback curto, profissional, seguro e motivador.
Não incentive aumento exagerado de carga.
Priorize técnica, constância e evolução gradual.
''';

    return _executarChamadaGemini(prompt, forcarJson: false);
  }

  Future<Map<String, dynamic>> analisarRefeicaoPorFoto(
    Uint8List bytesImagem,
  ) async {
    const prompt = '''
Aja como um nutricionista esportivo especialista em estimativa visual de refeições.

Analise a imagem desta refeição. Identifique os alimentos visíveis, estime as porções e calcule os macronutrientes aproximados.

Regras obrigatórias:
- Use prato, talheres, copos, marmitas e recipientes como referência de escala.
- Evite exagerar calorias por causa de foto tirada muito perto.
- Seja realista e conservador.
- Se não tiver certeza, informe uma estimativa média.
- Não dê diagnóstico médico.
- Não escreva texto fora do JSON.

Responda estritamente em JSON válido, sem markdown, com estas chaves exatas:

{
  "descricao": "Descrição resumida do prato com peso aproximado",
  "calorias": 520,
  "proteinas": 42,
  "carboidratos": 55,
  "gorduras": 18
}
''';

    try {
      String respostaPura = await _executarChamadaGemini(
        prompt,
        forcarJson: true,
        bytesImagem: bytesImagem,
      );

      if (respostaPura.startsWith("ERRO_")) {
        debugPrint("[AIService] Erro no scanner de refeição: $respostaPura");
        return {
          'descricao': 'Falha ao processar alimentos na imagem.',
          'calorias': 0.0,
          'proteinas': 0.0,
          'carboidratos': 0.0,
          'gorduras': 0.0,
        };
      }

      String jsonLimpo = _limparJson(respostaPura);

      final Map<String, dynamic> dados = jsonDecode(jsonLimpo);

      return {
        'descricao': dados['descricao']?.toString() ?? 'Refeição estimada',
        'calorias': _converterNumero(dados['calorias']),
        'proteinas': _converterNumero(dados['proteinas']),
        'carboidratos': _converterNumero(dados['carboidratos']),
        'gorduras': _converterNumero(dados['gorduras']),
      };
    } catch (e) {
      debugPrint("[AIService] Erro na análise multimodal da imagem: $e");

      return {
        'descricao': 'Falha ao processar alimentos na imagem.',
        'calorias': 0.0,
        'proteinas': 0.0,
        'carboidratos': 0.0,
        'gorduras': 0.0,
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
Você é um Personal Trainer experiente.

Monte uma estrutura completa de treino focado em "$objetivo" para o nível de experiência "$nivel".

Use exclusivamente estes exercícios:
${exerciciosDisponiveis.join(', ')}

Não invente exercícios fora desta lista.

Retorne obrigatoriamente um objeto JSON válido seguindo exatamente esta estrutura:

{
  "treinos": [
    {
      "nome": "Treino A",
      "exercicios": [
        {
          "nome": "Nome do Exercício",
          "series": 4,
          "repeticoes": 12,
          "descanso": "60s"
        }
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
        "A API do Gemini barrou a requisição. Erro 429. Veja o RESPONSE BODY detalhado no terminal do VS Code.",
      );
    }

    if (respostaPura == "ERRO_CONEXAO" ||
        respostaPura.startsWith("ERRO_STATUS_") ||
        respostaPura.startsWith("ERRO_AUTH") ||
        respostaPura.startsWith("ERRO_SEM_CANDIDATES") ||
        respostaPura.startsWith("ERRO_RESPOSTA_VAZIA")) {
      throw Exception(
        "O serviço de IA retornou uma inconsistência: $respostaPura",
      );
    }

    String jsonLimpo = _limparJson(respostaPura);

    try {
      final Map<String, dynamic> dados = jsonDecode(jsonLimpo);

      if (!dados.containsKey('treinos')) {
        return {'treinos': []};
      }

      return dados;
    } catch (e) {
      debugPrint("[AIService] Falha ao decodificar JSON de treino: $e");
      debugPrint("[AIService] Resposta recebida: $jsonLimpo");

      throw Exception("Falha ao decodificar a estrutura de treinos.");
    }
  }
}
