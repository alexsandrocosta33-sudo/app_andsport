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

  // CONTROLES ADICIONADOS PARA EDIÇÃO DE ALUNOEXISTENTE
  final _editarNomeAlunoController = TextEditingController();
  final _editarEmailAlunoController = TextEditingController();

  // Valores Locais de Backup (caso o banco esteja vazio na primeira execução)
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
  String? _alunoSelecionadoEmail; // Guardando e-mail para edição
  bool _eProfessor = false;
  bool _carregandoPerfil = true;

  String _fichaSelecionadaAluno = 'A';
  String _grupoSelecionadoParaNovoExercicio = 'Peito';

  int _abaAtualProfessor = 0;

  final Map<String, List<Map<String, String>>> _bancoExercicios = {
    'Peito': [
      {
        'nome': 'Supino Reto Barra',
        'video': 'https://www.youtube.com/watch?v=sqOw2Y6u9p4',
      },
      {
        'nome': 'Supino Inclinado Halteres',
        'video': 'https://www.youtube.com/watch?v=Z1rC3TBCXvU',
      },
      {
        'nome': 'Crucifixo Máquina',
        'video': 'https://www.youtube.com/watch?v=4as_MvM8TGY',
      },
      {
        'nome': 'Cross Over',
        'video': 'https://www.youtube.com/watch?v=H75t3r_N3Uo',
      },
    ],
    'Costas': [
      {
        'nome': 'Puxada Aberta Pulley',
        'video': 'https://www.youtube.com/watch?v=84SgEshA6oo',
      },
      {
        'nome': 'Remada Baixa Triângulo',
        'video': 'https://www.youtube.com/watch?v=xQ_F9gO8z6E',
      },
      {
        'nome': 'Pull Down Corda',
        'video': 'https://www.youtube.com/watch?v=7_hE0tPHeLw',
      },
    ],
    'Bíceps': [
      {
        'nome': 'Rosca Direta Barra W',
        'video': 'https://www.youtube.com/watch?v=0wVbNkaM5IE',
      },
      {
        'nome': 'Rosca Alternada Halteres',
        'video': 'https://www.youtube.com/watch?v=sMc4nPP6b_g',
      },
    ],
    'Tríceps': [
      {
        'nome': 'Tríceps Pulley Corda',
        'video': 'https://www.youtube.com/watch?v=d_KInV6_E8Q',
      },
      {
        'nome': 'Tríceps Testa',
        'video': 'https://www.youtube.com/watch?v=vV77O0vscb8',
      },
    ],
    'Pernas': [
      {
        'nome': 'Agachamento Livre',
        'video': 'https://www.youtube.com/watch?v=68R87r9x1bM',
      },
      {
        'nome': 'Leg Press 45',
        'video': 'https://www.youtube.com/watch?v=0Enwby_n7wM',
      },
      {
        'nome': 'Cadeira Extensora',
        'video': 'https://www.youtube.com/watch?v=WcoYfSgYfIk',
      },
    ],
    'Ombros': [
      {
        'nome': 'Desenvolvimento Halteres',
        'video': 'https://www.youtube.com/watch?v=r0wI4O-8H88',
      },
      {
        'nome': 'Elevação Lateral',
        'video': 'https://www.youtube.com/watch?v=2K4VbE3C8m4',
      },
    ],
  };

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

  // --- FUNÇÃO PARA O PROFESSOR EDITAR NOME E EMAIL DO ALUNO ---
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
                  content: Text('Dados do aluno atualizados com sucesso! 📝'),
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

  // --- FUNÇÃO PARA REMOVER O ALUNO DEFINITIVAMENTE DO BANCO ---
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
          'Tem certeza que deseja apagar o cadastro de "$_alunoSelecionadoNome"? Todos os treinos e o histórico financeiro dele serão excluídos permanentemente.',
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

              // Limpa a seleção na tela primeiro para evitar erros de renderização
              setState(() {
                _alunoSelecionadoId = null;
                _alunoSelecionadoNome = null;
                _alunoSelecionadoEmail = null;
              });

              // Deleta o documento do aluno principal no Firestore
              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(idParaDeletar)
                  .delete();

              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Aluno removido do sistema.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
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
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Alterar Tabela Base',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Altere os valores base padrão para cada plano da sua academia:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _editMensalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Plano Mensal (Reais)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _editTrimestralController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Plano Trimestral (Reais)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _editSemestralController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Plano Semestral (Reais)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _editAnualController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Plano Anual (Reais)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.amber,
              ),
              onPressed: () async {
                double m = double.tryParse(_editMensalController.text) ?? 80.0;
                double t =
                    double.tryParse(_editTrimestralController.text) ?? 220.0;
                double s =
                    double.tryParse(_editSemestralController.text) ?? 420.0;
                double a = double.tryParse(_editAnualController.text) ?? 800.0;

                await FirebaseFirestore.instance
                    .collection('configuracoes')
                    .doc('planos')
                    .set({
                      'Mensal': m,
                      'Trimestral': t,
                      'Semestral': s,
                      'Anual': a,
                    }, SetOptions(merge: true));

                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Atualizar Banco'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirGerenciamentoFinanceiro(
    String alunoId,
    String nomeAluno,
    Map<String, dynamic> dadosAtuais,
  ) {
    _planoSelecionadoAluno = dadosAtuais['plano'] ?? 'Mensal';

    if (dadosAtuais['valorMensalidade'] != null) {
      _mensalidadeController.text = dadosAtuais['valorMensalidade'].toString();
    } else {
      _mensalidadeController.text =
          (_valoresPlanosCarregados[_planoSelecionadoAluno] ?? 80.0).toString();
    }

    _vencimentoController.text = (dadosAtuais['diaVencimento'] ?? 10)
        .toString();
    _statusPagamentoSelecionado = dadosAtuais['statusPagamento'] ?? 'Pendente';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          title: Text(
            'Financeiro: $nomeAluno',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _planoSelecionadoAluno,
                    decoration: const InputDecoration(
                      labelText: 'Plano Contratado',
                      border: OutlineInputBorder(),
                    ),
                    items: _valoresPlanosCarregados.keys.map((plano) {
                      return DropdownMenuItem(value: plano, child: Text(plano));
                    }).toList(),
                    onChanged: (novoPlano) {
                      if (novoPlano != null) {
                        setPopupState(() {
                          _planoSelecionadoAluno = novoPlano;
                          _mensalidadeController.text =
                              (_valoresPlanosCarregados[novoPlano] ?? 80.0)
                                  .toString();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mensalidadeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor Cobrado (Reais)',
                      border: OutlineInputBorder(),
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _vencimentoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dia do Vencimento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _statusPagamentoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Status Atual',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Pago', 'Pendente', 'Atrasado'].map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null)
                        setPopupState(() => _statusPagamentoSelecionado = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'Confirmar Recebimento (Dar Baixa)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      double valor =
                          double.tryParse(_mensalidadeController.text) ?? 0.0;
                      int dia = int.tryParse(_vencimentoController.text) ?? 10;

                      await _registrarPagamentoNoBancoInterno(
                        alunoId: alunoId,
                        valorPago: valor,
                        plano: _planoSelecionadoAluno,
                        diaVencimento: dia,
                      );

                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pagamento registrado no histórico com sucesso! ✔',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const Text(
                    '📜 Histórico de Recibos Anteriores:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(alunoId)
                          .collection('pagamentos')
                          .orderBy('dataPagamento', descending: true)
                          .snapshots(),
                      builder: (context, histSnapshot) {
                        if (!histSnapshot.hasData)
                          return const Center(
                            child: LinearProgressIndicator(color: Colors.amber),
                          );
                        final recibos = histSnapshot.data!.docs;
                        if (recibos.isEmpty) {
                          return const Text(
                            'Nenhum pagamento registrado no histórico ainda.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: recibos.length,
                          itemBuilder: (context, hIndex) {
                            final rData =
                                recibos[hIndex].data() as Map<String, dynamic>;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.receipt_long,
                                color: Colors.green,
                                size: 20,
                              ),
                              title: Text(
                                'Ref: ${rData['mesReferencia'] ?? '---'} (${rData['plano'] ?? 'Mensal'})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Pago: R\$ ${(rData['valorPago'] ?? 0.0).toStringAsFixed(2)}',
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Fechar',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.amber,
              ),
              onPressed: () async {
                double valor =
                    double.tryParse(_mensalidadeController.text) ?? 0.0;
                int dia = int.tryParse(_vencimentoController.text) ?? 10;

                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(alunoId)
                    .update({
                      'valorMensalidade': valor,
                      'diaVencimento': dia,
                      'statusPagamento': _statusPagamentoSelecionado,
                      'plano': _planoSelecionadoAluno,
                    });
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }

  void _assistirVideo(String? url) async {
    if (url == null || url.isEmpty || url == '---') return;
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _adicionarExercicioAoCardapio() {
    String nomeExercicio = _novoExercicioCardapioController.text.trim();
    if (nomeExercicio.isEmpty) return;
    setState(() {
      _bancoExercicios[_grupoSelecionadoParaNovoExercicio]!.add({
        'nome': nomeExercicio,
        'video': '---',
      });
      _novoExercicioCardapioController.clear();
    });
  }

  void _removerExercicioDoCardapio(
    String group,
    Map<String, String> exercicioMap,
  ) {
    setState(() => _bancoExercicios[group]!.remove(exercicioMap));
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
            const SizedBox(height: 8),
            TextField(
              controller: _seriesController,
              decoration: const InputDecoration(
                labelText: 'Séries x Repetições',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cargaController,
              decoration: const InputDecoration(labelText: 'Carga (kg)'),
            ),
            const SizedBox(height: 8),
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
              if (treinoId != null)
                await _workoutService.excluirTreino(
                  _alunoSelecionadoId!,
                  treinoId,
                );
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
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

    // =========================================================================
    // ABA DE TREINOS COM EXPANSÃO PARA EDITAR E EXCLUIR ALUNOS
    // =========================================================================
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.amber,
                      ),
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

          // ROW REESTRUTURADO DO DROPDOWN COM BOTÕES DE EDIÇÃO E EXCLUSÃO
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
              // BOTÕES EXCLUSIVOS DO PROFESSOR CASO ALGUM ALUNO ESTEJA SELECIONADO
              if (_alunoSelecionadoId != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  tooltip: 'Editar nome/email do aluno',
                  onPressed: _abrirEdicaoDadosAluno,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'Excluir aluno do sistema',
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
                      '➕ Cadastrar Novo Exercício no Cardápio:',
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
                                items: _bancoExercicios.keys
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
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _adicionarExercicioAoCardapio,
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '📋 Cardápio de Exercícios (Clique para Adicionar/Editar):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Column(
              children: _bancoExercicios.keys.map((grupo) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: Colors.white,
                  child: ExpansionTile(
                    title: Text(
                      'Treino de $grupo',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: _bancoExercicios[grupo]!.map((item) {
                      return ListTile(
                        title: Text(item['nome']!),
                        leading: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              _removerExercicioDoCardapio(grupo, item),
                        ),
                        trailing: const Icon(
                          Icons.add_circle,
                          color: Colors.amber,
                        ),
                        onTap: () => _abrirConfiguracaoExercicio(
                          grupo,
                          item['nome']!,
                          videoUrlAtual: item['video'],
                        ),
                      );
                    }).toList(),
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
                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: IconButton(
                        icon: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.amber,
                          size: 34,
                        ),
                        onPressed: () => _assistirVideo(dados?['videoUrl']),
                      ),
                      title: Text(
                        dados?['exercicios'] ?? 'Exercício',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${dados?['grupo'] ?? ''} | Séries: ${dados?['series'] ?? ''} | Carga: ${dados?['carga'] ?? ''}',
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
                                  onPressed: () => _abrirConfiguracaoExercicio(
                                    dados?['grupo'] ?? '',
                                    dados?['exercicios'] ?? '',
                                    treinoId: t.id,
                                    seriesAtual: dados?['series'],
                                    cargaAtual: dados?['carga'],
                                    videoUrlAtual: dados?['videoUrl'],
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
                          : const Icon(Icons.fitness_center),
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
