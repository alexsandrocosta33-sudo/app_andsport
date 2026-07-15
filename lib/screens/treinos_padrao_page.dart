import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/workout_service.dart';

class TreinosPadraoPage extends StatefulWidget {
  final bool eAdmin;
  const TreinosPadraoPage({super.key, required this.eAdmin});

  @override
  State<TreinosPadraoPage> createState() => _TreinosPadraoPageState();
}

class _TreinosPadraoPageState extends State<TreinosPadraoPage> {
  final WorkoutService _service = WorkoutService();

  String _nivel = 'Iniciante';
  String _perfil = 'Feminino';

  static const List<String> _niveis = ['Iniciante', 'Intermediário', 'Avançado'];
  static const List<String> _perfis = ['Feminino', 'Masculino'];
  static const List<String> _fichas = ['A', 'B', 'C', 'D'];
  static const List<String> _grupos = [
    'Peito', 'Costas', 'Pernas', 'Ombros', 'Bíceps', 'Tríceps', 'Abdômen', 'Cardio',
  ];

  // -------------------------------------------------------------------------
  // Dados iniciais para popular o Firestore (copiados do modelo hardcoded)
  // -------------------------------------------------------------------------
  static final List<Map<String, String>> _exerciciosIniciante = [
    {'ficha': 'A', 'grupo': 'Peito',    'exercicio': 'Supino Reto na Máquina',       'series': '3x12', 'carga': '20 kg'},
    {'ficha': 'A', 'grupo': 'Peito',    'exercicio': 'Pec Deck (Voador)',             'series': '3x12', 'carga': '25 kg'},
    {'ficha': 'A', 'grupo': 'Tríceps',  'exercicio': 'Tríceps Pulley',               'series': '3x12', 'carga': '15 kg'},
    {'ficha': 'B', 'grupo': 'Pernas',   'exercicio': 'Leg Press 45º',                'series': '3x15', 'carga': '60 kg'},
    {'ficha': 'B', 'grupo': 'Pernas',   'exercicio': 'Cadeira Extensora',            'series': '3x12', 'carga': '20 kg'},
    {'ficha': 'C', 'grupo': 'Costas',   'exercicio': 'Puxada Aberta no Pulley',      'series': '3x12', 'carga': '25 kg'},
    {'ficha': 'C', 'grupo': 'Bíceps',   'exercicio': 'Rosca Direta com Halteres',    'series': '3x12', 'carga': '6 kg'},
  ];

  static final List<Map<String, String>> _exerciciosIntermediario = [
    {'ficha': 'A', 'grupo': 'Peito',    'exercicio': 'Supino Reto com Barra',           'series': '4x10', 'carga': '40 kg'},
    {'ficha': 'A', 'grupo': 'Peito',    'exercicio': 'Supino Inclinado com Halteres',   'series': '4x10', 'carga': '16 kg'},
    {'ficha': 'A', 'grupo': 'Tríceps',  'exercicio': 'Tríceps Testa',                   'series': '4x10', 'carga': '10 kg'},
    {'ficha': 'B', 'grupo': 'Pernas',   'exercicio': 'Agachamento Livre',               'series': '4x10', 'carga': '30 kg'},
    {'ficha': 'B', 'grupo': 'Pernas',   'exercicio': 'Mesa Flexora',                    'series': '4x10', 'carga': '25 kg'},
    {'ficha': 'C', 'grupo': 'Costas',   'exercicio': 'Remada Baixa Sentado',            'series': '4x10', 'carga': '40 kg'},
    {'ficha': 'C', 'grupo': 'Bíceps',   'exercicio': 'Rosca Scott',                     'series': '4x10', 'carga': '12 kg'},
    {'ficha': 'D', 'grupo': 'Ombros',   'exercicio': 'Desenvolvimento com Halteres',    'series': '4x10', 'carga': '12 kg'},
  ];

  static final List<Map<String, String>> _exerciciosAvancado = [
    {'ficha': 'A', 'grupo': 'Peito',    'exercicio': 'Supino Reto no Smith',            'series': '4x8',  'carga': '60 kg'},
    {'ficha': 'A', 'grupo': 'Peito',    'exercicio': 'Crucifixo Inclinado em Banco',    'series': '4x10', 'carga': '20 kg'},
    {'ficha': 'A', 'grupo': 'Tríceps',  'exercicio': 'Tríceps Pulley com Corda',        'series': '4x12', 'carga': '25 kg'},
    {'ficha': 'B', 'grupo': 'Pernas',   'exercicio': 'Agachamento Livre Pesado',        'series': '4x8',  'carga': '70 kg'},
    {'ficha': 'B', 'grupo': 'Pernas',   'exercicio': 'Cadeira Flexora',                 'series': '4x12', 'carga': '40 kg'},
    {'ficha': 'C', 'grupo': 'Costas',   'exercicio': 'Remada Curvada com Barra',        'series': '4x8',  'carga': '50 kg'},
    {'ficha': 'C', 'grupo': 'Bíceps',   'exercicio': 'Rosca Direta na Barra W',         'series': '4x10', 'carga': '20 kg'},
    {'ficha': 'D', 'grupo': 'Ombros',   'exercicio': 'Elevação Lateral na Polia',       'series': '4x12', 'carga': '10 kg'},
  ];

  String get _modeloId => WorkoutService.gerarModeloId(_nivel, _perfil);

  // -------------------------------------------------------------------------
  // Popular dados iniciais no Firestore
  // -------------------------------------------------------------------------
  Future<void> _popularDadosIniciais() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.upload_outlined, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Popular Dados Iniciais?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Isso irá gravar no Firestore os modelos padrão para todos os 6 perfis:\n\n'
          '• Iniciante Feminino\n• Iniciante Masculino\n'
          '• Intermediário Feminino\n• Intermediário Masculino\n'
          '• Avançado Feminino\n• Avançado Masculino\n\n'
          'Modelos já existentes não serão apagados — apenas novos exercícios serão adicionados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );

    try {
      final modelos = {
        'Iniciante':     {'Feminino': _exerciciosIniciante,    'Masculino': _exerciciosIniciante},
        'Intermediário': {'Feminino': _exerciciosIntermediario, 'Masculino': _exerciciosIntermediario},
        'Avançado':      {'Feminino': _exerciciosAvancado,     'Masculino': _exerciciosAvancado},
      };

      for (final nivel in modelos.keys) {
        for (final perfil in modelos[nivel]!.keys) {
          final existente = await _service.modeloPadraoExiste(WorkoutService.gerarModeloId(nivel, perfil));
          if (!existente) {
            await _service.popularModeloInicial(nivel, perfil, modelos[nivel]![perfil]!);
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Modelos iniciais gravados com sucesso no Firestore!'),
          backgroundColor: Colors.green[800],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao popular dados: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Formulário de criar / editar exercício — seleção pela Biblioteca
  // -------------------------------------------------------------------------
  void _abrirFormularioExercicio({DocumentSnapshot? doc}) {
    final dados = doc?.data() as Map<String, dynamic>?;

    String ficha = dados?['ficha']?.toString() ?? 'A';
    String grupo = dados?['grupo']?.toString() ?? 'Peito';
    if (!_fichas.contains(ficha)) ficha = 'A';
    if (!_grupos.contains(grupo)) grupo = 'Peito';

    // Exercício da biblioteca (preenchido automaticamente ao selecionar)
    String? exercicioBibliotecaId = dados?['exercicioBibliotecaId']?.toString();
    String  nomeExercicio         = dados?['exercicio']?.toString()  ?? '';
    String  videoUrlExercicio     = dados?['videoUrl']?.toString()   ?? '---';

    // Campos editáveis pelo professor
    final seriesController = TextEditingController(text: dados?['series']?.toString() ?? '3x12');
    final cargaController  = TextEditingController(text: dados?['carga']?.toString()  ?? '---');
    final ordemController  = TextEditingController(
      text: dados?['ordem'] != null && dados!['ordem'] != 0 ? dados['ordem'].toString() : '',
    );

    // Future para carregar a biblioteca filtrada por grupo (recarregado ao mudar grupo)
    Future<List<QueryDocumentSnapshot>> carregarBiblioteca(String g) async {
      final snap = await FirebaseFirestore.instance
          .collection('exercicios')
          .where('grupo', isEqualTo: g)
          .get();
      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final nA = a.get('nome')?.toString() ?? '';
        final nB = b.get('nome')?.toString() ?? '';
        return nA.toLowerCase().compareTo(nB.toLowerCase());
      });
      return docs;
    }

    var futureBiblioteca = carregarBiblioteca(grupo);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(doc == null ? Icons.add_circle : Icons.edit, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  doc == null ? 'Novo Exercício' : 'Editar Exercício',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Ficha ──────────────────────────────────────────────
                    DropdownButtonFormField<String>(
                      initialValue: ficha,
                      decoration: const InputDecoration(
                        labelText: 'Ficha *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _fichas
                          .map((f) => DropdownMenuItem(value: f, child: Text('Ficha $f')))
                          .toList(),
                      onChanged: (v) => setLocal(() => ficha = v!),
                    ),
                    const SizedBox(height: 12),

                    // ── Grupo muscular ─────────────────────────────────────
                    DropdownButtonFormField<String>(
                      initialValue: grupo,
                      decoration: const InputDecoration(
                        labelText: '1. Grupo Muscular *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _grupos
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setLocal(() {
                        grupo = v!;
                        // Resetar seleção de exercício ao mudar o grupo
                        exercicioBibliotecaId = null;
                        nomeExercicio = '';
                        videoUrlExercicio = '---';
                        futureBiblioteca = carregarBiblioteca(grupo);
                      }),
                    ),
                    const SizedBox(height: 12),

                    // ── Exercício da Biblioteca ────────────────────────────
                    const Text(
                      '2. Exercício da Biblioteca *',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder<List<QueryDocumentSnapshot>>(
                      future: futureBiblioteca,
                      builder: (context, snap) {
                        // Carregando
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(color: Colors.deepPurple),
                          );
                        }

                        // Erro de permissão ou conexão
                        if (snap.hasError) {
                          final err = snap.error.toString();
                          final msg = err.contains('permission-denied') ||
                                  err.contains('PERMISSION_DENIED')
                              ? 'Sem permissão para acessar a Biblioteca de Exercícios.'
                              : 'Erro ao carregar biblioteca: $err';
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                                const SizedBox(width: 6),
                                Expanded(child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12))),
                              ],
                            ),
                          );
                        }

                        final docs = snap.data ?? [];

                        // Nenhum exercício neste grupo
                        if (docs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 16),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Nenhum exercício cadastrado para este grupo.\nCadastre primeiro na Biblioteca de Exercícios.',
                                    style: TextStyle(color: Colors.orange, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // IDs válidos para o grupo atual
                        final idsValidos = docs.map((d) => d.id).toSet();
                        final valorDropdown = idsValidos.contains(exercicioBibliotecaId)
                            ? exercicioBibliotecaId
                            : null;

                        return DropdownButtonFormField<String>(
                          initialValue: valorDropdown,
                          hint: const Text('Selecione o exercício...'),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          isExpanded: true,
                          items: docs.map((d) {
                            final ex = d.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(
                                ex['nome']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (id) {
                            if (id == null) return;
                            final docEx = docs.firstWhere((d) => d.id == id);
                            final ex = docEx.data() as Map<String, dynamic>;
                            setLocal(() {
                              exercicioBibliotecaId = id;
                              nomeExercicio = ex['nome']?.toString() ?? '';
                              videoUrlExercicio = ex['videoUrl']?.toString() ?? '---';
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // ── Exercício selecionado (preview automático) ─────────
                    if (nomeExercicio.isNotEmpty) ...[
                      Container(
                        width: double.maxFinite,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.fitness_center, size: 14, color: Colors.deepPurple),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    nomeExercicio,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.videocam_outlined, size: 13, color: Colors.blueGrey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    videoUrlExercicio != '---' ? videoUrlExercicio : 'Sem vídeo cadastrado',
                                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Séries x repetições ────────────────────────────────
                    TextField(
                      controller: seriesController,
                      decoration: const InputDecoration(
                        labelText: 'Séries x Repetições *',
                        hintText: 'Ex: 4x12',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Carga ──────────────────────────────────────────────
                    TextField(
                      controller: cargaController,
                      decoration: const InputDecoration(
                        labelText: 'Carga padrão',
                        hintText: 'Ex: 20 kg  (ou --- para sem carga)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Ordem ──────────────────────────────────────────────
                    TextField(
                      controller: ordemController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ordem (opcional)',
                        hintText: 'Ex: 1',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.save),
                label: const Text('Salvar'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(context);

                  // Validação: deve ter exercício da biblioteca selecionado
                  if (exercicioBibliotecaId == null || nomeExercicio.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Selecione um exercício da Biblioteca antes de salvar.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  final series = seriesController.text.trim();
                  if (series.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Séries e repetições são obrigatórias.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  final carga = cargaController.text.trim().isEmpty
                      ? '---'
                      : cargaController.text.trim();
                  final ordem = int.tryParse(ordemController.text.trim()) ?? 0;

                  final dadosSalvar = {
                    'ficha':                 ficha,
                    'grupo':                 grupo,
                    'exercicio':             nomeExercicio,
                    'exercicioBibliotecaId': exercicioBibliotecaId!,
                    'series':                series,
                    'carga':                 carga,
                    'videoUrl':              videoUrlExercicio,
                    'ordem':                 ordem,
                  };

                  try {
                    await _service.salvarExercicioPadrao(
                      _modeloId,
                      dadosSalvar,
                      exercicioId: doc?.id,
                    );

                    // Garante que o documento pai existe
                    await FirebaseFirestore.instance
                        .collection('treinos_padrao')
                        .doc(_modeloId)
                        .set({
                      'nivel': _nivel,
                      'perfil': _perfil,
                      'atualizadoEm': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (!mounted) return;
                    nav.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Exercício salvo com sucesso!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Erro ao salvar exercício: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Confirmação de exclusão
  // -------------------------------------------------------------------------
  void _confirmarExclusao(String exercicioId, String nomeExercicio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Excluir Exercício?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Remover "$nomeExercicio" do modelo padrão $_nivel / $_perfil?\n\n'
          'Isso não afeta treinos já aplicados a alunos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete),
            label: const Text('Excluir'),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _service.excluirExercicioPadrao(_modeloId, exercicioId);
                if (!mounted) return;
                nav.pop();
              } catch (e) {
                if (!mounted) return;
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Card de exercício na lista
  // -------------------------------------------------------------------------
  Widget _buildExercicioCard(QueryDocumentSnapshot doc) {
    final dados  = doc.data() as Map<String, dynamic>;
    final nome   = dados['exercicio']?.toString() ?? '';
    final grupo  = dados['grupo']?.toString()     ?? '';
    final series = dados['series']?.toString()    ?? '';
    final carga  = dados['carga']?.toString()     ?? '---';
    final video  = dados['videoUrl']?.toString()  ?? '---';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.withValues(alpha: 0.12),
          child: const Icon(Icons.fitness_center, color: Colors.deepPurple, size: 20),
        ),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(
          '$grupo  •  $series  •  $carga'
          '${video != '---' ? '  •  📹' : ''}',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 20),
              tooltip: 'Editar',
              onPressed: () => _abrirFormularioExercicio(doc: doc),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              tooltip: 'Excluir',
              onPressed: () => _confirmarExclusao(doc.id, nome),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build principal
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
        title: const Text('Editar Treinos Padrão'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Popular dados iniciais no Firestore',
            onPressed: _popularDadosIniciais,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Seletores de nível e perfil ──────────────────────────────────
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _nivel,
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Nível',
                          labelStyle: TextStyle(color: Colors.amber),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber, width: 2),
                          ),
                        ),
                        items: _niveis
                            .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Text(n, style: const TextStyle(color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _nivel = v!),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _perfil,
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Perfil',
                          labelStyle: TextStyle(color: Colors.amber),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber, width: 2),
                          ),
                        ),
                        items: _perfis
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p, style: const TextStyle(color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _perfil = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Modelo: $_modeloId',
                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de exercícios ──────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _service.listarExerciciosPadrao(_modeloId),
              builder: (context, snapshot) {
                // Erro de permissão ou outro
                if (snapshot.hasError) {
                  final err = snapshot.error.toString();
                  final msg = err.contains('permission-denied') ||
                          err.contains('PERMISSION_DENIED')
                      ? 'Sem permissão para acessar os treinos padrão.\nVerifique as regras do Firestore.'
                      : 'Erro ao carregar exercícios: $err';
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Carregando
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  );
                }

                final docs = snapshot.data!.docs;

                // Vazio
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fitness_center, size: 52, color: Colors.grey[400]),
                          const SizedBox(height: 14),
                          Text(
                            'Nenhum exercício cadastrado para\n$_nivel / $_perfil.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Clique em + para adicionar exercícios\nou use o ícone ↑ no topo para carregar os modelos base.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Ordenar por ficha → ordem
                final sorted = docs.toList()
                  ..sort((a, b) {
                    final da = a.data() as Map<String, dynamic>;
                    final db = b.data() as Map<String, dynamic>;
                    final fichaA = (da['ficha'] ?? 'A').toString();
                    final fichaB = (db['ficha'] ?? 'A').toString();
                    final cmpFicha = fichaA.compareTo(fichaB);
                    if (cmpFicha != 0) return cmpFicha;
                    final ordemA = int.tryParse((da['ordem'] ?? 0).toString()) ?? 0;
                    final ordemB = int.tryParse((db['ordem'] ?? 0).toString()) ?? 0;
                    return ordemA.compareTo(ordemB);
                  });

                // Agrupar por ficha
                final Map<String, List<QueryDocumentSnapshot>> porFicha = {};
                for (final doc in sorted) {
                  final ficha = ((doc.data() as Map<String, dynamic>)['ficha'] ?? 'A').toString();
                  porFicha.putIfAbsent(ficha, () => []).add(doc);
                }

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final ficha in ['A', 'B', 'C', 'D'])
                      if (porFicha.containsKey(ficha)) ...[
                        // Cabeçalho da ficha
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: Colors.deepPurple,
                                child: Text(
                                  ficha,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ficha $ficha  (${porFicha[ficha]!.length} exercício${porFicha[ficha]!.length != 1 ? 's' : ''})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final doc in porFicha[ficha]!) _buildExercicioCard(doc),
                      ],
                    const SizedBox(height: 80), // espaço para o FAB
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        tooltip: 'Adicionar exercício ao modelo',
        onPressed: () => _abrirFormularioExercicio(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
