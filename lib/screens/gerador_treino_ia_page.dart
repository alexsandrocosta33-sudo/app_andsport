import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_andsport/services/ai_service.dart';

class GeradorTreinoIAPage extends StatefulWidget {
  const GeradorTreinoIAPage({Key? key}) : super(key: key);

  @override
  State<GeradorTreinoIAPage> createState() => _GeradorTreinoIAPageState();
}

class _GeradorTreinoIAPageState extends State<GeradorTreinoIAPage> {
  final AIService _aiService = AIService();

  String? _idAlunoSelecionado;
  String _objetivoSelecionado = 'Hipertrofia';
  String _nivelSelecionado = 'Intermediário';

  bool _estaCarregando = false;
  String? _resultadoTexto;

  final List<String> _exerciciosBackup = [
    'Supino Reto Barra',
    'Supino Inclinado Halteres',
    'Voador Pectoral',
    'Puxada Alta Pronada',
    'Remada Baixa Triângulo',
    'Remada Cavalinho',
    'Desenvolvimento Halteres',
    'Elevação Lateral',
    'Rosca Direta Barra',
    'Rosca Alternada',
    'Tríceps Pulley',
    'Tríceps Testa',
    'Agachamento Livre',
    'Leg Press 45',
    'Cadeira Extensora',
    'Mesa Flexora',
  ];

  Future<Map<String, Map<String, dynamic>>>
  _carregarCatalogoExerciciosEmMemoria() async {
    Map<String, Map<String, dynamic>> mapaExercicios = {};
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('exercicios')
          .get();
      for (var doc in snapshot.docs) {
        var dados = doc.data();
        String nomeKey = (dados['nome'] ?? '').toString().trim();
        if (nomeKey.isNotEmpty) {
          mapaExercicios[nomeKey] = dados;
        }
      }
    } catch (e) {
      debugPrint('[GeradorTreinoIA] Erro ao carregar catálogo: $e');
    }
    return mapaExercicios;
  }

  Future<void> _gerarECadastrarTreinoReal() async {
    if (_idAlunoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um aluno na lista.'),
        ),
      );
      return;
    }

    setState(() {
      _estaCarregando = true;
      _resultadoTexto = null;
    });

    try {
      var catalogoLocal = await _carregarCatalogoExerciciosEmMemoria();
      List<String> exerciciosFiltroPrompt = catalogoLocal.keys.toList();

      if (exerciciosFiltroPrompt.isEmpty) {
        exerciciosFiltroPrompt = _exerciciosBackup;
      }

      debugPrint('[GeradorTreinoIA] Aluno: $_idAlunoSelecionado | Exercícios na biblioteca: ${exerciciosFiltroPrompt.length}');

      // CHAMADA ALINHADA: Parâmetro definido estritamente como 'objetivo' em português
      final Map<String, dynamic> treinoMap = await _aiService.gerarTreinoEmJson(
        objetivo: _objetivoSelecionado,
        nivel: _nivelSelecionado,
        exerciciosDisponiveis: exerciciosFiltroPrompt,
      );

      debugPrint('[GeradorTreinoIA] Resposta JSON da IA: ${jsonEncode(treinoMap)}');

      final firestore = FirebaseFirestore.instance;

      final CollectionReference treinosRef = firestore
          .collection('usuarios')
          .doc(_idAlunoSelecionado)
          .collection('treinos');

      // Limpeza automática para evitar acúmulo ou duplicações na grade
      final treinosAntigosSnap = await treinosRef.get();
      for (var docAntigo in treinosAntigosSnap.docs) {
        await docAntigo.reference.delete();
      }

      List<dynamic> blocosTreino = treinoMap['treinos'];
      int totalCadastrados = 0;

      for (var bloco in blocosTreino) {
        String nomeBlocoOriginal = bloco['nome'] ?? bloco['name'] ?? 'Treino A';
        String nomeUpper = nomeBlocoOriginal.toUpperCase().trim();

        String letraFicha = 'A';
        if (nomeUpper.startsWith('TREINO B') || nomeUpper == 'B') {
          letraFicha = 'B';
        } else if (nomeUpper.startsWith('TREINO C') ||
            nomeUpper == 'C' ||
            nomeUpper.startsWith('TREINO D')) {
          letraFicha = 'C';
        }

        List<dynamic> exerciciosSugeridos = bloco['exercicios'] ?? [];

        for (var ex in exerciciosSugeridos) {
          String nomeExercicio = (ex['nome'] ?? ex['name'] ?? 'Exercício')
              .toString()
              .trim();

          String videoUrlDoCatologo = '---';
          String grupoMuscularDoCatalogo = 'Peito';

          if (catalogoLocal.containsKey(nomeExercicio)) {
            var dadosDoExercicio = catalogoLocal[nomeExercicio]!;
            videoUrlDoCatologo = dadosDoExercicio['videoUrl'] ?? '---';
            grupoMuscularDoCatalogo = dadosDoExercicio['grupo'] ?? 'Peito';
          } else {
            String nomeLower = nomeExercicio.toLowerCase();
            if (nomeLower.contains('supino') ||
                nomeLower.contains('crucifixo') ||
                nomeLower.contains('voador'))
              grupoMuscularDoCatalogo = 'Peito';
            if (nomeLower.contains('puxada') ||
                nomeLower.contains('remada') ||
                nomeLower.contains('pulley'))
              grupoMuscularDoCatalogo = 'Costas';
            if (nomeLower.contains('rosca')) grupoMuscularDoCatalogo = 'Bíceps';
            if (nomeLower.contains('testa') || nomeLower.contains('tríceps'))
              grupoMuscularDoCatalogo = 'Tríceps';
            if (nomeLower.contains('desenvolvimento') ||
                nomeLower.contains('elevação'))
              grupoMuscularDoCatalogo = 'Ombros';
            if (nomeLower.contains('agachamento') ||
                nomeLower.contains('leg') ||
                nomeLower.contains('extensora'))
              grupoMuscularDoCatalogo = 'Pernas';
          }

          int seriesSugeridas = ex['series'] ?? 4;
          String repsSugeridas = ex['repeticoes']?.toString() ?? '10';
          String tempoDescanso = ex['descanso']?.toString() ?? '60s';

          // Gravação cirúrgica mapeada 100% igual ao formato de leitura da HomeScreen
          await treinosRef.add({
            'exercicios': nomeExercicio,
            'grupo': grupoMuscularDoCatalogo,
            'ficha': letraFicha,
            'series': "${seriesSugeridas}x$repsSugeridas",
            'carga': '---',
            'descanso': tempoDescanso,
            'videoUrl': videoUrlDoCatologo,
            'criadoEm': FieldValue.serverTimestamp(),
          });
          totalCadastrados++;
        }
      }

      setState(() {
        _resultadoTexto =
            "Ficha Atualizada com Êxito!\nProcessados $totalCadastrados exercícios limpos na grade da Ficha do Aluno sem duplicações.";
      });
    } catch (e) {
      setState(() {
        _resultadoTexto = "Aviso de consistência do processo: $e";
      });
    } finally {
      setState(() {
        _estaCarregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Automação de Fichas (v2.0)'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '1. Aluno Selecionado para Receber a Ficha IA:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const LinearProgressIndicator(color: Colors.amber);

                var listaAlunosDocs = snapshot.data!.docs.where((doc) {
                  var cargo = (doc.data() as Map)['cargo'] ?? 'aluno';
                  return cargo == 'aluno';
                }).toList();

                if (listaAlunosDocs.isEmpty) {
                  return const Text(
                    'Nenhum aluno ativo encontrado no banco.',
                    style: TextStyle(color: Colors.red),
                  );
                }

                return DropdownButtonFormField<String>(
                  initialValue: _idAlunoSelecionado,
                  hint: const Text('Selecione o Aluno da Academia'),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  items: listaAlunosDocs.map((doc) {
                    var dados = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(dados['nome'] ?? 'Aluno sem Nome'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _idAlunoSelecionado = val),
                );
              },
            ), // Fechamento estrutural corrigido com sucesso
            const SizedBox(height: 16),

            const Text(
              '2. Ajustes de Filtro da IA:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _objetivoSelecionado,
              decoration: const InputDecoration(
                labelText: 'Objetivo',
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
              ),
              items:
                  [
                        'Hipertrofia',
                        'Emagrecimento',
                        'Definição',
                        'Condicionamento',
                      ]
                      .map(
                        (obj) => DropdownMenuItem<String>(
                          value: obj,
                          child: Text(obj),
                        ),
                      )
                      .toList(),
              onChanged: (val) => setState(() => _objetivoSelecionado = val!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _nivelSelecionado,
              decoration: const InputDecoration(
                labelText: 'Nível de Experiência',
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
              ),
              items: ['Iniciante', 'Intermediário', 'Avançado']
                  .map(
                    (niv) =>
                        DropdownMenuItem<String>(value: niv, child: Text(niv)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _nivelSelecionado = val!),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _estaCarregando ? null : _gerarECadastrarTreinoReal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _estaCarregando
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      'Gerar Ficha Inteligente & Limpar Antiga',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            if (_resultadoTexto != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Text(
                  _resultadoTexto!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
