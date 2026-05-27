import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Controles de Texto
  final _grupoController = TextEditingController();
  final _seriesController = TextEditingController();
  final _cargaController = TextEditingController();
  final _novoNomeController = TextEditingController();
  final _novoEmailController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _novoExercicioCardapioController = TextEditingController();
  final _videoUrlController = TextEditingController();

  // CONTROLES DE CADASTRO DE PROFESSOR
  final _profNomeController = TextEditingController();
  final _profEmailController = TextEditingController();
  final _profSenhaController = TextEditingController();

  // CONTROLES DO PAINEL FINANCEIRO
  final _mensalidadeController = TextEditingController();
  final _vencimentoController = TextEditingController();
  String _statusPagamentoSelecionado = 'Pendente';
  String _planoSelecionadoAluno = 'Mensal';

  // CONTROLES PARA EDICAO DOS PLANOS DO CARDAPIO
  final _editMensalController = TextEditingController();
  final _editTrimestralController = TextEditingController();
  final _editSemestralController = TextEditingController();
  final _editAnual = TextEditingController();

  // CONTROLES PARA EDIÇÃO DE ALUNO EXISTENTE
  final _editarNomeAlunoController = TextEditingController();
  final _editarEmailAlunoController = TextEditingController();

  // Controle de busca de alunos
  String _filtroBuscaAlunos = '';

  // Variaveis para o vinculo de exercicio armazenado
  String? _exercicioSelecionadoCardapio;
  String _grupoSelecionadoFiltro = 'Peito';

  Map<String, double> _valoresPlanosCarregados = {
    'Mensal': 80.0,
    'Trimestral': 220.0,
    'Semestral': 420.0,
    'Anual': 800.0,
  };

  final _workoutService = WorkoutService();
  final _authService = AuthService();
  final _auth = FirebaseAuth.instance;

  String? _alunoSelecionadoId;
  String? _alunoSelecionadoNome;
  String? _alunoSelecionadoEmail;

  // HIERARQUIA DE PERMISSÕES
  bool _eProfessor = false;
  bool _eAdminGeral = false;
  bool _carregandoPerfil = true;

  String _fichaSelecionadaAluno = 'A';
  String _grupoSelecionadoParaNovoExercicio = 'Peito';
  int _abaAtualProfessor = 0;

  final List<String> _gruposMusculares = [
    'Peito',
    'Costas',
    'Pernas',
    'Ombros',
    'Bíceps',
    'Tríceps',
    'Abdômen',
    'Cardio',
  ];

  @override
  void initState() {
    super.initState();
    _verificarPerfil();
    _ouvirValoresDoCardapioDePlanos();
  }

  void _verificarPerfil() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final emailLogado = user.email?.toLowerCase().trim() ?? '';

    if (emailLogado == 'alexsandrocosta33@gmail.com') {
      setState(() {
        _eAdminGeral = true;
        _eProfessor = true;
        _alunoSelecionadoId = null;
        _carregandoPerfil = false;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: user.email?.trim())
          .get();

      if (snap.docs.isNotEmpty) {
        final dadosUsuario = snap.docs.first.data();
        String cargo = dadosUsuario['cargo'] ?? 'aluno';

        if (cargo == 'admin') {
          setState(() {
            _eAdminGeral = true;
            _eProfessor = true;
            _alunoSelecionadoId = null;
            _carregandoPerfil = false;
          });
        } else if (cargo == 'professor' ||
            emailLogado.contains('admin') ||
            emailLogado.contains('professor')) {
          setState(() {
            _eAdminGeral = false;
            _eProfessor = true;
            _alunoSelecionadoId = null;
            _carregandoPerfil = false;
          });
        } else {
          setState(() {
            _eAdminGeral = false;
            _eProfessor = false;
            _alunoSelecionadoId = snap.docs.first.id;
            _carregandoPerfil = false;
          });
        }
        return;
      }
    } catch (e) {
      print("Erro ao sincronizar perfil: $e");
    }

    setState(() {
      _alunoSelecionadoId = user.uid;
      _eProfessor = false;
      _eAdminGeral = false;
      _carregandoPerfil = false;
    });
  }

  void _ouvirValoresDoCardapioDePlanos() {
    FirebaseFirestore.instance
        .collection('configuracoes')
        .doc('planos')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final dados = snapshot.data()!;
            setState(() {
              _valoresPlanosCarregados = {
                'Mensal': double.tryParse(dados['Mensal'].toString()) ?? 80.0,
                'Trimestral':
                    double.tryParse(dados['Trimestral'].toString()) ?? 220.0,
                'Semestral':
                    double.tryParse(dados['Semestral'].toString()) ?? 420.0,
                'Anual': double.tryParse(dados['Anual'].toString()) ?? 800.0,
              };
            });
          }
        });
  }

  @override
  void dispose() {
    _grupoController.dispose();
    _seriesController.dispose();
    _cargaController.dispose();
    _novoNomeController.dispose();
    _novoEmailController.dispose();
    _novaSenhaController.dispose();
    _novoExercicioCardapioController.dispose();
    _videoUrlController.dispose();
    _profNomeController.dispose();
    _profEmailController.dispose();
    _profSenhaController.dispose();
    _mensalidadeController.dispose();
    _vencimentoController.dispose();
    _editMensalController.dispose();
    _editTrimestralController.dispose();
    _editSemestralController.dispose();
    _editAnual.dispose();
    _editarNomeAlunoController.dispose();
    _editarEmailAlunoController.dispose();
    super.dispose();
  }

  void _cadastrarNovoProfessor() async {
    if (_profNomeController.text.isEmpty ||
        _profEmailController.text.isEmpty ||
        _profSenhaController.text.isEmpty)
      return;

    try {
      await _authService.professorCadastrarAluno(
        nome: _profNomeController.text.trim(),
        email: _profEmailController.text.trim(),
        senha: _profSenhaController.text.trim(),
      );

      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: _profEmailController.text.trim())
          .get();

      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({'cargo': 'professor'});
      }

      _profNomeController.clear();
      _profEmailController.clear();
      _profSenhaController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Professor credenciado com sucesso! 🛡️'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print("Erro ao cadastrar professor: $e");
    }
  }

  void _abrirEdicaoDadosAluno() {
    if (_alunoSelecionadoId == null) return;

    _editarNomeAlunoController.text = _alunoSelecionadoNome ?? '';
    _editarEmailAlunoController.text = _alunoSelecionadoEmail ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Editar Cadastro do Aluno',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _editarNomeAlunoController,
              decoration: const InputDecoration(
                labelText: 'Nome do Aluno',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editarEmailAlunoController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail de Acesso',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.amber,
            ),
            onPressed: () async {
              if (_editarNomeAlunoController.text.trim().isEmpty) return;

              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(_alunoSelecionadoId)
                  .update({
                    'nome': _editarNomeAlunoController.text.trim(),
                    'email': _editarEmailAlunoController.text.trim(),
                  });

              setState(() {
                _alunoSelecionadoNome = _editarNomeAlunoController.text.trim();
                _alunoSelecionadoEmail = _editarEmailAlunoController.text
                    .trim();
              });

              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dados do aluno atualizados! 📝'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _confirmarExclusaoAluno() {
    if (_alunoSelecionadoId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Excluir Aluno?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Tem certeza que deseja apagar o cadastro de "$_alunoSelecionadoNome"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final idParaDeletar = _alunoSelecionadoId!;
              setState(() {
                _alunoSelecionadoId = null;
                _alunoSelecionadoNome = null;
                _alunoSelecionadoEmail = null;
              });

              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(idParaDeletar)
                  .delete();
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Excluir Definitivamente'),
          ),
        ],
      ),
    );
  }

  void _abrirConfiguracaoDeValoresDoCardapio() {
    _editMensalController.text = _valoresPlanosCarregados['Mensal'].toString();
    _editTrimestralController.text = _valoresPlanosCarregados['Trimestral']
        .toString();
    _editSemestralController.text = _valoresPlanosCarregados['Semestral']
        .toString();
    _editAnual.text = _valoresPlanosCarregados['Anual'].toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar Tabela Base'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _editMensalController,
              decoration: const InputDecoration(labelText: 'Plano Mensal'),
            ),
            TextField(
              controller: _editTrimestralController,
              decoration: const InputDecoration(labelText: 'Plano Trimestral'),
            ),
            TextField(
              controller: _editSemestralController,
              decoration: const InputDecoration(labelText: 'Plano Semestral'),
            ),
            TextField(
              controller: _editAnual,
              decoration: const InputDecoration(labelText: 'Plano Anual'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('configuracoes')
                  .doc('planos')
                  .set({
                    'Mensal':
                        double.tryParse(_editMensalController.text) ?? 80.0,
                    'Trimestral':
                        double.tryParse(_editTrimestralController.text) ??
                        220.0,
                    'Semestral':
                        double.tryParse(_editSemestralController.text) ?? 420.0,
                    'Anual': double.tryParse(_editAnual.text) ?? 800.0,
                  }, SetOptions(merge: true));
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  void _abrirGerenciamentoFinanceiro(
    String alunoId,
    String nomeAluno,
    Map<String, dynamic> dadosAtuais,
  ) {
    _planoSelecionadoAluno = dadosAtuais['plano'] ?? 'Mensal';
    _mensalidadeController.text =
        (dadosAtuais['valorMensalidade'] ??
                _valoresPlanosCarregados[_planoSelecionadoAluno])
            .toString();
    _vencimentoController.text = (dadosAtuais['diaVencimento'] ?? 10)
        .toString();
    _statusPagamentoSelecionado = dadosAtuais['statusPagamento'] ?? 'Pendente';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          title: Text('Financeiro: $nomeAluno'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _planoSelecionadoAluno,
                items: _valoresPlanosCarregados.keys
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setPopupState(() {
                  _planoSelecionadoAluno = v!;
                  _mensalidadeController.text = _valoresPlanosCarregados[v]
                      .toString();
                }),
              ),
              TextField(
                controller: _mensalidadeController,
                decoration: const InputDecoration(labelText: 'Valor'),
              ),
              TextField(
                controller: _vencimentoController,
                decoration: const InputDecoration(
                  labelText: 'Vencimento (Dia)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _statusPagamentoSelecionado,
                items: ['Pago', 'Pendente', 'Atrasado']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) =>
                    setPopupState(() => _statusPagamentoSelecionado = v!),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(alunoId)
                    .update({
                      'valorMensalidade':
                          double.tryParse(_mensalidadeController.text) ?? 0.0,
                      'diaVencimento':
                          int.tryParse(_vencimentoController.text) ?? 10,
                      'statusPagamento': _statusPagamentoSelecionado,
                      'plano': _planoSelecionadoAluno,
                    });
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _assistirVideo(String? url) {
    if (url == null || url.isEmpty || url == '---') return;

    final videoId = YoutubePlayerController.convertUrlToId(url);
    if (videoId == null) return;

    final playerController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
        mute: true,
        loop: true,
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      barrierColor: Colors.black.withOpacity(0.75),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(controller: playerController),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber,
                        ),
                        onPressed: () {
                          playerController.close();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close, size: 22),
                        label: const Text(
                          'Fechar Treino',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _adicionarExercicioAoCardapio() async {
    String nomeExercicio = _novoExercicioCardapioController.text.trim();
    String linkVideo = _videoUrlController.text.trim();

    if (nomeExercicio.isEmpty) return;

    await FirebaseFirestore.instance.collection('exercicios').add({
      'nome': nomeExercicio,
      'grupo': _grupoSelecionadoParaNovoExercicio,
      'videoUrl': linkVideo.isEmpty ? '---' : linkVideo,
      'criadoEm': FieldValue.serverTimestamp(),
    });

    _novoExercicioCardapioController.clear();
    _videoUrlController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exercício salvo na biblioteca! ✔'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _abrirConfiguracaoExercicio(
    String group,
    String exercise, {
    String? treinoId,
    String? seriesAtual,
    String? cargaAtual,
    String? videoUrlAtual,
  }) {
    if (_alunoSelecionadoId == null) return;
    _seriesController.text = seriesAtual ?? '4x10';
    _cargaController.text = cargaAtual != null
        ? cargaAtual.replaceAll(' kg', '')
        : '';
    _videoUrlController.text = videoUrlAtual ?? '---';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          treinoId == null
              ? 'Vincular ao Treino $_fichaSelecionadaAluno'
              : 'Editar Exercício',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Exercício: $exercise',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _seriesController,
              decoration: const InputDecoration(
                labelText: 'Séries x Repetições',
              ),
            ),
            TextField(
              controller: _cargaController,
              decoration: const InputDecoration(labelText: 'Carga (kg)'),
            ),
            TextField(
              controller: _videoUrlController,
              decoration: const InputDecoration(
                labelText: 'Link do Vídeo (Opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _workoutService.salvarTreino(
                alunoId: _alunoSelecionadoId!,
                ficha: _fichaSelecionadaAluno,
                grupoMuscular: group,
                nomeExercicios: exercise,
                seriesRepeticoes: _seriesController.text,
                carga: _cargaController.text.isEmpty
                    ? '---'
                    : '${_cargaController.text} kg',
                videoUrl: _videoUrlController.text,
              );

              if (treinoId != null) {
                await _workoutService.excluirTreino(
                  _alunoSelecionadoId!,
                  treinoId,
                );
              }

              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Adicionar ao Aluno'),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalhesExercicioAluno(Map<String, dynamic> dados) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.fitness_center, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dados['exercicios'] ?? 'Exercício',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grupo Muscular: ${dados['grupo'] ?? '---'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Séries e Repetições: ${dados['series'] ?? '---'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Carga Configurada: ${dados['carga'] ?? '---'}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar', style: TextStyle(color: Colors.black)),
          ),
          if (dados['videoUrl'] != null &&
              dados['videoUrl'] != '---' &&
              dados['videoUrl'].toString().isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.amber,
              ),
              onPressed: () {
                Navigator.pop(context);
                _assistirVideo(dados['videoUrl']);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Ver Execução'),
            ),
        ],
      ),
    );
  }

  void _limparFichaCompleta() async {
    if (_alunoSelecionadoId == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_alunoSelecionadoId)
        .collection('treinos')
        .where('ficha', isEqualTo: _fichaSelecionadaAluno)
        .get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  void _matricularNovoAluno() async {
    if (_novoNomeController.text.isEmpty ||
        _novoEmailController.text.isEmpty ||
        _novaSenhaController.text.isEmpty)
      return;
    try {
      await _authService.professorCadastrarAluno(
        nome: _novoNomeController.text.trim(),
        email: _novoEmailController.text.trim(),
        senha: _novaSenhaController.text.trim(),
      );

      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: _novoEmailController.text.trim())
          .get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({
          'cargo': 'aluno',
          'statusPagamento': 'Pendente',
          'diaVencimento': 10,
          'plano': 'Mensal',
          'valorMensalidade': 80.0,
        });
      }

      _novoNomeController.clear();
      _novoEmailController.clear();
      _novaSenhaController.clear();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aluno matriculado com sucesso! 🚀'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print(e);
    }
  }

  void _removerExercicioDoCardapio(String docId) async {
    await FirebaseFirestore.instance
        .collection('exercicios')
        .doc(docId)
        .delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exercício removido da biblioteca.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Color _obterCorStatus(String status) {
    if (status == 'Pago') return Colors.green;
    if (status == 'Atrasado') return Colors.red;
    return Colors.orange;
  }

  // NOVA INTERFACE VISUAL: Constrói o card de status de validade e mensagem na visão do aluno
  Widget _construirCardValidadeMensalidade(Map<String, dynamic> dados) {
    String status = dados['statusPagamento'] ?? 'Pendente';
    int diaVencimento = dados['diaVencimento'] ?? 10;
    int diaHoje = DateTime.now().day;

    // Se o status no banco for Pendente mas o dia atual já passou do vencimento, consideramos Atrasado dinamicamente
    bool estaAtrasado =
        status == 'Atrasado' ||
        (status == 'Pendente' && diaHoje > diaVencimento);
    bool estaPago = status == 'Pago';

    Color corCard = estaPago
        ? Colors.green[700]!
        : (estaAtrasado ? Colors.red[700]! : Colors.orange[700]!);
    IconData icone = estaPago
        ? Icons.check_circle
        : (estaAtrasado ? Icons.warning : Icons.hourglass_empty);

    return Card(
      elevation: 3,
      color: corCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  estaPago
                      ? 'Mensalidade em Dia'
                      : (estaAtrasado
                            ? 'Atenção: Mensalidade Vencida'
                            : 'Mensalidade Pendente'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Plano Atual: ${dados['plano'] ?? 'Mensal'} • Vencimento: Dia $diaVencimento de cada mês.',
              style: const TextStyle(color: Colors.white90, fontSize: 13),
            ),
            // Se estiver atrasado, exibe a mensagem amigável solicitada
            if (estaAtrasado) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: Colors.white30, height: 1),
              ),
              const Text(
                'Olá! Passamos para lembrar que sua mensalidade venceu. Para continuar acessando seus treinos e evoluindo com a gente, por favor, regularize sua situação na recepção. Bons treinos! 💪',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================== ABAS DO PROFESSOR CONSTRUÍDAS ==================

  Widget _construirAbaTreinos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_eAdminGeral) ...[
          Card(
            elevation: 3,
            color: Colors.blueGrey[900],
            child: ExpansionTile(
              iconColor: Colors.amber,
              collapsedIconColor: Colors.amber,
              leading: const Icon(Icons.shield, color: Colors.amber),
              title: const Text(
                'Área do Dono: Cadastrar Professor',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _profNomeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nome do Professor',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _profEmailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'E-mail de Acesso',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _profSenhaController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Senha Inicial',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(42),
                        ),
                        onPressed: _cadastrarNovoProfessor,
                        child: const Text(
                          'Autorizar e Cadastrar Professor',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        Card(
          elevation: 2,
          color: Colors.white,
          child: ExpansionTile(
            leading: const Icon(Icons.bookmark, color: Colors.blueAccent),
            title: const Text(
              'Gerenciar Biblioteca de Exercícios',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _grupoSelecionadoParaNovoExercicio,
                      decoration: const InputDecoration(
                        labelText: 'Grupo Muscular',
                        border: OutlineInputBorder(),
                      ),
                      items: _gruposMusculares
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (val) => setState(
                        () => _grupoSelecionadoParaNovoExercicio = val!,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _novoExercicioCardapioController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Exercício (Ex: Supino Reto)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _videoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Link do Vídeo no YouTube',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(42),
                      ),
                      onPressed: _adicionarExercicioAoCardapio,
                      child: const Text('Salvar na Biblioteca'),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Exercícios Salvos:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),

                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('exercicios')
                          .orderBy('criadoEm', descending: true)
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox();
                        var lista = snap.data!.docs;
                        if (lista.isEmpty)
                          return const Text(
                            'Nenhum exercício armazenado ainda.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          );
                        return SizedBox(
                          height: 180,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: lista.length,
                            itemBuilder: (context, i) {
                              var item =
                                  lista[i].data() as Map<String, dynamic>;
                              return ListTile(
                                dense: true,
                                title: Text(item['nome'] ?? ''),
                                subtitle: Text(item['grupo'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      _removerExercicioDoCardapio(lista[i].id),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Card(
          elevation: 2,
          color: Colors.white,
          child: ExpansionTile(
            leading: const Icon(Icons.person_add, color: Colors.black),
            title: const Text(
              'Matricular Novo Aluno',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _novoNomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Completo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _novoEmailController,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _novaSenhaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha de Acesso',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.amber,
                        minimumSize: const Size.fromHeight(45),
                      ),
                      onPressed: _matricularNovoAluno,
                      child: const Text('Salvar Matrícula'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          onChanged: (val) =>
              setState(() => _filtroBuscaAlunos = val.toLowerCase().trim()),
          decoration: InputDecoration(
            labelText: 'Buscar Aluno...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'Selecione um Aluno para Ver/Montar a Ficha:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );

            var alunos = snapshot.data!.docs.where((doc) {
              var dados = doc.data() as Map<String, dynamic>;
              String nome = (dados['nome'] ?? '').toString().toLowerCase();
              String cargo = dados['cargo'] ?? 'aluno';
              return nome.contains(_filtroBuscaAlunos) && cargo == 'aluno';
            }).toList();

            if (alunos.isEmpty) return const Text('Nenhum aluno encontrado.');

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alunos.length,
              itemBuilder: (context, index) {
                var doc = alunos[index];
                var dados = doc.data() as Map<String, dynamic>;
                bool selecionado = _alunoSelecionadoId == doc.id;

                return Card(
                  color: selecionado ? Colors.amber[100] : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.amber,
                      child: Text(
                        dados['nome']?[0].toString().toUpperCase() ?? 'A',
                      ),
                    ),
                    title: Text(
                      dados['nome'] ?? 'Sem nome',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Vence dia: ${dados['diaVencimento'] ?? 10} | Status: ${dados['statusPagamento'] ?? 'Pendente'}',
                    ),
                    trailing: selecionado
                        ? const Icon(Icons.check_circle, color: Colors.black)
                        : null,
                    onTap: () {
                      setState(() {
                        _alunoSelecionadoId = doc.id;
                        _alunoSelecionadoNome = dados['nome'];
                        _alunoSelecionadoEmail = dados['email'];
                        _exercicioSelecionadoCardapio = null;
                      });
                    },
                    onLongPress: () {
                      setState(() {
                        _alunoSelecionadoId = doc.id;
                        _alunoSelecionadoNome = dados['nome'];
                        _alunoSelecionadoEmail = dados['email'];
                      });
                      _abrirEdicaoDadosAluno();
                    },
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),

        if (_alunoSelecionadoId != null) ...[
          Divider(color: Colors.grey[400]),
          Text(
            'Vinculando Exercício para: $_alunoSelecionadoNome',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Escolha pela Biblioteca Armazenada',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _grupoSelecionadoFiltro,
                    decoration: const InputDecoration(
                      labelText: '1. Selecione o Grupo Muscular',
                      border: OutlineInputBorder(),
                    ),
                    items: _gruposMusculares
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _grupoSelecionadoFiltro = val!;
                        _exercicioSelecionadoCardapio = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('exercicios')
                        .where('grupo', isEqualTo: _grupoSelecionadoFiltro)
                        .snapshots(),
                    builder: (context, snapEx) {
                      if (!snapEx.hasData)
                        return const LinearProgressIndicator();
                      var docsEx = snapEx.data!.docs;

                      if (docsEx.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Nenhum exercício deste grupo salvo na biblioteca.',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        value: _exercicioSelecionadoCardapio,
                        hint: const Text('2. Escolha o Exercício'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: docsEx.map((de) {
                          var exData = de.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: "${exData['nome']}|||${exData['videoUrl']}",
                            child: Text(exData['nome'] ?? ''),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _exercicioSelecionadoCardapio = val),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.amber,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    onPressed: _exercicioSelecionadoCardapio == null
                        ? null
                        : () {
                            var partes = _exercicioSelecionadoCardapio!.split(
                              "|||",
                            );
                            String nomeEx = partes[0];
                            String urlVid = partes[1];
                            _abrirConfiguracaoExercicio(
                              _grupoSelecionadoFiltro,
                              nomeEx,
                              videoUrlAtual: urlVid,
                            );
                          },
                    icon: const Icon(Icons.add_task),
                    label: const Text('Definir Cargas e Séries'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _construirAbaFinanceira() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Status de Mensalidades Gerais',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.black),
              onPressed: _abrirConfiguracaoDeValoresDoCardapio,
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );

            var docs = snapshot.data!.docs.where((doc) {
              var d = doc.data() as Map<String, dynamic>;
              return (d['cargo'] ?? 'aluno') == 'aluno';
            }).toList();

            if (docs.isEmpty)
              return const Text('Nenhum aluno ativo para faturamento.');

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                var doc = docs[index];
                var dados = doc.data() as Map<String, dynamic>;
                String status = dados['statusPagamento'] ?? 'Pendente';

                return Card(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      dados['nome'] ?? 'Aluno',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Plano: ${dados['plano'] ?? 'Mensal'} | Vencimento: dia ${dados['diaVencimento'] ?? 10}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _obterCorStatus(status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _obterCorStatus(status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () => _abrirGerenciamentoFinanceiro(
                      doc.id,
                      dados['nome'] ?? 'Aluno',
                      dados,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ================== CONSTRUTOR DE INTERFACE PRINCIPAL (BUILD) ==================

  @override
  Widget build(BuildContext context) {
    if (_carregandoPerfil) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
        title: Text(
          _eProfessor
              ? (_abaAtualProfessor == 0
                    ? (_eAdminGeral
                          ? 'Painel Admin Geral'
                          : 'Painel do Professor')
                    : 'Gestão Financeira 💰')
              : 'Meus Treinos',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final nav = Navigator.of(context);
              await _authService.deslogar();
              nav.pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _eProfessor
            ? (_abaAtualProfessor == 0
                  ? Column(
                      children: [
                        _construirAbaTreinos(),
                        if (_alunoSelecionadoId != null) ...[
                          const SizedBox(height: 16),
                          _construirListaDeTreinosEfetivos(),
                        ],
                      ],
                    )
                  : _construirAbaFinanceira())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sincroniza dinamicamente as informações financeiras do aluno logado na tela dele
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(_alunoSelecionadoId)
                        .snapshots(),
                    builder: (context, snapUser) {
                      if (!snapUser.hasData || !snapUser.data!.exists)
                        return const SizedBox();
                      var dadosCompletosAluno =
                          snapUser.data!.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _construirCardValidadeMensalidade(
                          dadosCompletosAluno,
                        ),
                      );
                    },
                  ),
                  _construirListaDeTreinosEfetivos(),
                ],
              ),
      ),
      bottomNavigationBar: _eProfessor
          ? BottomNavigationBar(
              currentIndex: _abaAtualProfessor,
              selectedItemColor: Colors.amber,
              unselectedItemColor: Colors.white,
              backgroundColor: Colors.black,
              onTap: (index) => setState(() => _abaAtualProfessor = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.fitness_center),
                  label: 'Treinos',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.monetization_on),
                  label: 'Financeiro',
                ),
              ],
            )
          : null,
    );
  }

  Widget _construirListaDeTreinosEfetivos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _eProfessor
                  ? 'Ficha Ativa de $_alunoSelecionadoNome:'
                  : 'Escolha a Série de Hoje:',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (_eProfessor)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                onPressed: _limparFichaCompleta,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: ['A', 'B', 'C'].map((letraFicha) {
            bool estaSelecionada = _fichaSelecionadaAluno == letraFicha;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: estaSelecionada
                        ? Colors.black
                        : Colors.white,
                    foregroundColor: estaSelecionada
                        ? Colors.amber
                        : Colors.black87,
                  ),
                  onPressed: () =>
                      setState(() => _fichaSelecionadaAluno = letraFicha),
                  child: Text('TREINO $letraFicha'),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _workoutService.listarTreinosPorFicha(
            _alunoSelecionadoId!,
            _fichaSelecionadaAluno,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );
            final treinos = snapshot.data?.docs ?? [];
            if (treinos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text('Nenhum exercício cadastrado nesta série.'),
                ),
              );
            }

            return Column(
              children: treinos.map((t) {
                final dadosTratados = t.data() as Map<String, dynamic>;

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: IconButton(
                            icon: const Icon(
                              Icons.play_circle_fill,
                              color: Colors.amber,
                              size: 36,
                            ),
                            onPressed: () =>
                                _assistirVideo(dadosTratados['videoUrl']),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!_eProfessor)
                                _mostrarDetalhesExercicioAluno(dadosTratados);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 4.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dadosTratados['exercicios'] ?? 'Exercício',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${dadosTratados['grupo'] ?? ''} | Reps: ${dadosTratados['series'] ?? ''} | Carga: ${dadosTratados['carga'] ?? ''}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_eProfessor)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                  size: 22,
                                ),
                                onPressed: () => _abrirConfiguracaoExercicio(
                                  dadosTratados['grupo'] ?? '',
                                  dadosTratados['exercicios'] ?? '',
                                  treinoId: t.id,
                                  seriesAtual: dadosTratados['series'],
                                  cargaAtual: dadosTratados['carga'],
                                  videoUrlAtual: dadosTratados['videoUrl'],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 22,
                                ),
                                onPressed: () => _workoutService.excluirTreino(
                                  _alunoSelecionadoId!,
                                  t.id,
                                ),
                              ),
                            ],
                          )
                        else
                          IconButton(
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.blueGrey,
                              size: 22,
                            ),
                            onPressed: () =>
                                _mostrarDetalhesExercicioAluno(dadosTratados),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
