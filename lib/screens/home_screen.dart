import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Controles de Texto existentes
  final _grupoController = TextEditingController();
  final _exerciciosController = TextEditingController();
  final _seriesController = TextEditingController();
  final _cargaController = TextEditingController();
  final _novoNomeController = TextEditingController();
  final _novoEmailController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _novoExercicioCardapioController = TextEditingController();
  final _videoUrlController = TextEditingController();

  // CONTROLES DO PAINEL FINANCEIRO
  final _mensalidadeController = TextEditingController();
  final _vencimentoController = TextEditingController();
  String _statusPagamentoSelecionado = 'Pendente';
  String _planoSelecionadoAluno = 'Mensal';

  // CONTROLES PARA EDICAO DOS PLANOS DO CARDAPIO
  final _editMensalController = TextEditingController();
  final _editTrimestralController = TextEditingController();
  final _editSemestralController = TextEditingController();
  final _editAnualController = TextEditingController();

  // CONTROLES ADICIONADOS PARA EDIÇÃO DE ALUNO EXISTENTE
  final _editarNomeAlunoController = TextEditingController();
  final _editarEmailAlunoController = TextEditingController();

  // Valores Locais de Backup
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
  bool _eProfessor = false;
  bool _carregandoPerfil = true;

  String _fichaSelecionadaAluno = 'A';
  String _grupoSelecionadoParaNovoExercicio = 'Peito';

  int _abaAtualProfessor = 0;

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

    if (emailLogado.contains('admin') ||
        emailLogado.contains('professor') ||
        emailLogado == 'alexsandrocosta33@gmail.com') {
      setState(() {
        _eProfessor = true;
        _alunoSelecionadoId = null;
        _carregandoPerfil = false;
      });
    } else {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('email', isEqualTo: user.email?.trim())
            .get();

        if (snap.docs.isNotEmpty) {
          setState(() {
            _alunoSelecionadoId = snap.docs.first.id;
            _eProfessor = false;
            _carregandoPerfil = false;
          });
          return;
        }
      } catch (e) {
        print("Erro ao sincronizar ID do aluno: $e");
      }

      setState(() {
        _alunoSelecionadoId = user.uid;
        _eProfessor = false;
        _carregandoPerfil = false;
      });
    }
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
    _exerciciosController.dispose();
    _seriesController.dispose();
    _cargaController.dispose();
    _novoNomeController.dispose();
    _novoEmailController.dispose();
    _novaSenhaController.dispose();
    _novoExercicioCardapioController.dispose();
    _videoUrlController.dispose();
    _mensalidadeController.dispose();
    _vencimentoController.dispose();
    _editMensalController.dispose();
    _editTrimestralController.dispose();
    _editSemestralController.dispose();
    _editAnualController.dispose();
    _editarNomeAlunoController.dispose();
    _editarEmailAlunoController.dispose();
    super.dispose();
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

  Future<void> _registrarPagamentoNoBancoInterno({
    required String alunoId,
    required double valorPago,
    required String plano,
    required int diaVencimento,
  }) async {
    final agora = DateTime.now();

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(alunoId)
        .collection('pagamentos')
        .add({
          'valorPago': valorPago,
          'plano': plano,
          'dataPagamento': Timestamp.fromDate(agora),
          'mesReferencia': '${agora.month}/${agora.year}',
        });

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(alunoId)
        .update({
          'statusPagamento': 'Pago',
          'valorMensalidade': valorPago,
          'diaVencimento': diaVencimento,
          'plano': plano,
        });
  }

  void _abrirConfiguracaoDeValoresDoCardapio() {
    _editMensalController.text = _valoresPlanosCarregados['Mensal'].toString();
    _editTrimestralController.text = _valoresPlanosCarregados['Trimestral']
        .toString();
    _editSemestralController.text = _valoresPlanosCarregados['Semestral']
        .toString();
    _editAnualController.text = _valoresPlanosCarregados['Anual'].toString();

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
              controller: _editAnualController,
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
                    'Anual':
                        double.tryParse(_editAnualController.text) ?? 800.0,
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
                decoration: const InputDecoration(labelText: 'Vencimento'),
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

  void _assistirVideo(String? url) async {
    if (url == null || url.isEmpty || url == '---') return;
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
        content: Text('Exercício e vídeo salvos no Firestore com sucesso! ✔'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removerExercicioDoCardapio(String docId) async {
    await FirebaseFirestore.instance
        .collection('exercicios')
        .doc(docId)
        .delete();
  }

  void _abrirConfiguracaoExercicio(
    String grupo,
    String exercicio, {
    String? treinoId,
    String? seriesAtual,
    String? cargaAtual,
    String? videoUrlAtual,
  }) {
    if (_alunoSelecionadoId == null) return;
    _grupoController.text = grupo;
    _exerciciosController.text = exercicio;
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
            Text('Exercício: $exercicio'),
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
              decoration: const InputDecoration(labelText: 'Link do Vídeo'),
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
                grupoMuscular: _grupoController.text,
                nomeExercicios: _exerciciosController.text,
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
            child: const Text('Adicionar'),
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
        nome: _novoNomeController.text,
        email: _novoEmailController.text,
        senha: _novaSenhaController.text,
      );
      _novoNomeController.clear();
      _novoEmailController.clear();
      _novaSenhaController.clear();
    } catch (e) {
      print(e);
    }
  }

  Color _obterCorStatus(String status) {
    if (status == 'Pago') return Colors.green;
    if (status == 'Atrasado') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoPerfil) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    Widget _construirAbaFinanceira() {
      return StreamBuilder<QuerySnapshot>(
        stream: _workoutService.listarTodosAlunos(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );

          final alunos = snapshot.data!.docs;
          double faturamentoTotal = 0;
          int pagos = 0;
          int pendentes = 0;

          for (var doc in alunos) {
            final dados = doc.data() as Map<String, dynamic>;
            final String emailAluno =
                dados['email']?.toString().toLowerCase() ?? '';

            if (emailAluno.contains('admin') ||
                emailAluno.contains('professor') ||
                emailAluno == 'alexsandrocosta33@gmail.com')
              continue;

            faturamentoTotal += (dados['valorMensalidade'] ?? 0.0);
            if (dados['statusPagamento'] == 'Pago') pagos++;
            if (dados['statusPagamento'] == 'Pendente' ||
                dados['statusPagamento'] == 'Atrasado')
              pendentes++;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.amber[50],
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.amber, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.style, color: Colors.amber, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Tabela de Preços (Cardápio)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _abrirConfiguracaoDeValoresDoCardapio,
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.settings,
                                  color: Colors.black54,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Editar Cardápio',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _valoresPlanosCarregados.entries.map((entry) {
                          return Column(
                            children: [
                              Text(
                                entry.key,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'R\$ ${entry.value.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.black,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Text(
                              'Previsão Total',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'R\$ ${faturamentoTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Text(
                              'Pagos',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '$pagos',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Text(
                              'Pendentes',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '$pendentes',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Alunos Ativos e Planos:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: alunos.length,
                itemBuilder: (context, index) {
                  final doc = alunos[index];
                  final dados = doc.data() as Map<String, dynamic>;
                  final String nome =
                      dados['nome'] ?? dados['email'] ?? 'Sem nome';
                  final String status = dados['statusPagamento'] ?? 'Pendente';
                  final double valor = dados['valorMensalidade'] ?? 0.0;
                  final int vencimento = dados['diaVencimento'] ?? 10;
                  final String plano = dados['plano'] ?? 'Mensal';
                  final String emailAluno =
                      dados['email']?.toString().toLowerCase() ?? '';

                  if (emailAluno.contains('admin') ||
                      emailAluno.contains('professor') ||
                      emailAluno == 'alexsandrocosta33@gmail.com') {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Row(
                        children: [
                          Text(
                            nome,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              plano,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Vence dia $vencimento | Valor: R\$ ${valor.toStringAsFixed(2)}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _obterCorStatus(status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _obterCorStatus(status)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: _obterCorStatus(status),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      onTap: () =>
                          _abrirGerenciamentoFinanceiro(doc.id, nome, dados),
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    }

    Widget _construirAbaTreinos() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpansionTile(
            title: const Text(
              'Matricular Novo Aluno',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            leading: const Icon(Icons.person_add, color: Colors.amber),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _novoNomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Aluno',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _novoEmailController,
                      decoration: const InputDecoration(
                        labelText: 'E-mail de Acesso',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _novaSenhaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha Inicial',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _matricularNovoAluno,
                      child: const Text('Confirmar Matrícula'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Selecione o Aluno para Gerenciar:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFBDBDBD)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _workoutService.listarTodosAlunos(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const LinearProgressIndicator(
                          color: Colors.amber,
                        );
                      final usuarios = snapshot.data!.docs;

                      final apenasAlunosreais = usuarios.where((doc) {
                        final email =
                            doc['email']?.toString().toLowerCase() ?? '';
                        return !email.contains('admin') &&
                            !email.contains('professor') &&
                            email != 'alexsandrocosta33@gmail.com';
                      }).toList();

                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _alunoSelecionadoId,
                          hint: const Text('Selecione um aluno ativo'),
                          isExpanded: true,
                          items: apenasAlunosreais
                              .map(
                                (doc) => DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(doc['nome'] ?? doc['email']),
                                ),
                              )
                              .toList(),
                          onChanged: (id) {
                            if (id == null) return;
                            final docEscolhido = usuarios.firstWhere(
                              (element) => element.id == id,
                            );
                            setState(() {
                              _alunoSelecionadoId = id;
                              _alunoSelecionadoNome =
                                  docEscolhido['nome'] ?? docEscolhido['email'];
                              _alunoSelecionadoEmail =
                                  docEscolhido['email'] ?? '';
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_alunoSelecionadoId != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: _abrirEdicaoDadosAluno,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: _confirmarExclusaoAluno,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (_alunoSelecionadoId != null) ...[
            Card(
              color: const Color(0xFFEEEEEE),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '➕ Cadastrar Novo Exercício no Firestore:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _grupoSelecionadoParaNovoExercicio,
                                items:
                                    [
                                          'Peito',
                                          'Costas',
                                          'Bíceps',
                                          'Tríceps',
                                          'Pernas',
                                          'Ombros',
                                        ]
                                        .map(
                                          (g) => DropdownMenuItem(
                                            value: g,
                                            child: Text(g),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) => setState(
                                  () => _grupoSelecionadoParaNovoExercicio = v!,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _novoExercicioCardapioController,
                            decoration: const InputDecoration(
                              labelText: 'Nome do Exercício',
                              border: OutlineInputBorder(),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _videoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Link do Vídeo do YouTube (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.video_library,
                          color: Colors.red,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.amber,
                      ),
                      onPressed: _adicionarExercicioAoCardapio,
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar no Banco de Dados'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '📋 Cardápio de Exercícios Dinâmico (Firestore):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),

            Column(
              children:
                  [
                    'Peito',
                    'Costas',
                    'Bíceps',
                    'Tríceps',
                    'Pernas',
                    'Ombros',
                  ].map((grupoNome) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.white,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('exercicios')
                            .where('grupo', isEqualTo: grupoNome)
                            .snapshots(),
                        builder: (context, exSnapshot) {
                          if (!exSnapshot.hasData)
                            return const LinearProgressIndicator(
                              color: Colors.amber,
                            );
                          final itensBanco = exSnapshot.data!.docs;

                          return ExpansionTile(
                            title: Text(
                              'Treino de $grupoNome (${itensBanco.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: itensBanco.map<Widget>((docEx) {
                              final item = docEx.data() as Map<String, dynamic>;
                              return ListTile(
                                title: Text(item['nome'] ?? ''),
                                subtitle: Text(
                                  'Vídeo: ${item['videoUrl'] ?? '---'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                leading: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _removerExercicioDoCardapio(docEx.id),
                                ),
                                trailing: const Icon(
                                  Icons.add_circle,
                                  color: Colors.amber,
                                ),
                                onTap: () => _abrirConfiguracaoExercicio(
                                  grupoNome,
                                  item['nome'] ?? '',
                                  videoUrlAtual: item['videoUrl'],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    );
                  }).toList(),
            ),
          ],
        ],
      );
    }

    Widget _construirListaDeTreinosEfetivos() {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _eProfessor
                    ? 'Gerenciando Ficha Ativa do Aluno:'
                    : 'Escolha a Série de Hoje:',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
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
              if (treinos.isEmpty)
                return const Center(
                  child: Text('Nenhum exercício cadastrado nesta série.'),
                );

              return Column(
                children: treinos.map((t) {
                  final dados = t.data() as Map<String, dynamic>?;
                  final dadosTratados = dados ?? {};

                  // BLINDAGEM DE CLIQUE: Usando InkWell para forçar o Card inteiro do aluno a responder ao toque
                  return Card(
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        if (!_eProfessor) {
                          _mostrarDetalhesExercicioAluno(dadosTratados);
                        }
                      },
                      child: ListTile(
                        leading: IconButton(
                          icon: const Icon(
                            Icons.play_circle_fill,
                            color: Colors.amber,
                            size: 34,
                          ),
                          onPressed: () =>
                              _assistirVideo(dadosTratados['videoUrl']),
                        ),
                        title: Text(
                          dadosTratados['exercicios'] ?? 'Exercício',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${dadosTratados['grupo'] ?? ''} | Séries: ${dadosTratados['series'] ?? ''} | Carga: ${dadosTratados['carga'] ?? ''}',
                        ),
                        trailing: _eProfessor
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.orange,
                                    ),
                                    onPressed: () =>
                                        _abrirConfiguracaoExercicio(
                                          dadosTratados['grupo'] ?? '',
                                          dadosTratados['exercicios'] ?? '',
                                          treinoId: t.id,
                                          seriesAtual: dadosTratados['series'],
                                          cargaAtual: dadosTratados['carga'],
                                          videoUrlAtual:
                                              dadosTratados['videoUrl'],
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _workoutService.excluirTreino(
                                          _alunoSelecionadoId!,
                                          t.id,
                                        ),
                                  ),
                                ],
                              )
                            : const Icon(
                                Icons.info_outline,
                                color: Colors.blueGrey,
                              ),
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

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
        title: Text(
          _eProfessor
              ? (_abaAtualProfessor == 0
                    ? 'Painel Admin'
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
                        if (_alunoSelecionadoId != null)
                          _construirListaDeTreinosEfetivos(),
                      ],
                    )
                  : _construirAbaFinanceira())
            : Column(
                children: [
                  if (_alunoSelecionadoId != null)
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
}
