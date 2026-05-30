import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';
import '../services/ai_service.dart';

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
  final _novoCelularController = TextEditingController();

  // VARIÁVEIS PARA ARMAZENAR A FOTO TIRADA NA HORA
  String? _fotoBase64NovaMatricula;
  String? _fotoBase64Edicao;

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
  final _editarCellularAlunoController = TextEditingController();

  // CONTROLE PARA ANOTAÇÃO DE CARGA PELO ALUNO
  final _anotarCargaController = TextEditingController();

  // VARIÁVEIS DO CRONÔMETRO DE DESCANSO EMBUTIDO
  Timer? _descansoTimer;
  int _tempoRestanteSegundos = 60;
  int _tempoDefinidoPadrao = 60;
  bool _cronometroAtivo = false;
  String _exercicioEmDescanso = '';

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
  final _aiService = AIService();
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

  Future<void> _tirarFotoNaHora(bool eEdicao) async {
    final picker = ImagePicker();
    try {
      final XFile? fotoCapturada = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 75,
      );

      if (fotoCapturada != null) {
        final bytes = await fotoCapturada.readAsBytes();
        setState(() {
          if (eEdicao) {
            _fotoBase64Edicao = base64Encode(bytes);
          } else {
            _fotoBase64NovaMatricula = base64Encode(bytes);
          }
        });
      }
    } catch (e) {
      print("Erro ao acessar camera: $e");
    }
  }

  void _iniciarCronometroDescanso(String nomeExercicio) {
    _descansoTimer?.cancel();
    setState(() {
      _exercicioEmDescanso = nomeExercicio;
      _tempoRestanteSegundos = _tempoDefinidoPadrao;
      _cronometroAtivo = true;
    });

    _descansoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_tempoRestanteSegundos > 0) {
        setState(() {
          _tempoRestanteSegundos--;
        });
      } else {
        _finalizarCronometro();
      }
    });
  }

  void _finalizarCronometro() {
    _descansoTimer?.cancel();
    setState(() {
      _cronometroAtivo = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Descanso Concluído para: $_exercicioEmDescanso! Hora da próxima série! 🔥',
          ),
          backgroundColor: Colors.amber[800],
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _cancelarCronometro() {
    _descansoTimer?.cancel();
    setState(() {
      _cronometroAtivo = false;
      _exercicioEmDescanso = '';
    });
  }

  Widget _construirBarraPainelCronometro() {
    if (!_cronometroAtivo) return const SizedBox();

    int minutes = _tempoRestanteSegundos ~/ 60;
    int seconds = _tempoRestanteSegundos % 60;
    String tempoFormatado = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.black, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tempo de Descanso',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _exercicioEmDescanso,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              color: Colors.black87,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                if (_tempoRestanteSegundos > 15) {
                  _tempoRestanteSegundos -= 15;
                  _tempoDefinidoPadrao = _tempoRestanteSegundos;
                }
              });
            },
          ),
          Text(
            tempoFormatado,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.black87,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _tempoRestanteSegundos += 15;
                _tempoDefinidoPadrao = _tempoRestanteSegundos;
              });
            },
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _cancelarCronometro,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black,
              child: Icon(Icons.close, size: 14, color: Colors.amber),
            ),
          ),
        ],
      ),
    );
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

  void _abrirEdicaoDadosAluno(Map<String, dynamic> dadosAtuais) {
    if (_alunoSelecionadoId == null) return;

    _editarNomeAlunoController.text = dadosAtuais['nome'] ?? '';
    _editarEmailAlunoController.text = dadosAtuais['email'] ?? '';
    _editarCellularAlunoController.text = dadosAtuais['celular'] ?? '';
    _fotoBase64Edicao = dadosAtuais['fotoBase64'] ?? '---';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Editar Cadastro',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setPopupState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Column(
                    children: [
                      _fotoBase64Edicao != '---' &&
                              _fotoBase64Edicao!.isNotEmpty
                          ? CircleAvatar(
                              radius: 45,
                              backgroundImage: MemoryImage(
                                base64Decode(_fotoBase64Edicao!),
                              ),
                            )
                          : const CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.black26,
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.orange,
                        ),
                        label: const Text(
                          'Atualizar Foto do Aluno',
                          style: TextStyle(color: Colors.orange),
                        ),
                        onPressed: () async {
                          await _tirarFotoNaHora(true);
                          setPopupState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _editarCellularAlunoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Número de Celular',
                    hintText: '(11) 99999-9999',
                    border: OutlineInputBorder(),
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
              'Cancelar',
              style: TextStyle(color: Colors.black),
            ),
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
                    'celular': _editarCellularAlunoController.text.trim(),
                    'fotoBase64': _fotoBase64Edicao ?? '---',
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

  void _confirmarExclusaoAluno(String idAluno, String nomeAluno) {
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
          'Tem certeza que deseja apagar permanentemente o cadastro de "$nomeAluno"? Todos os treinos vinculados serão perdidos.',
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
              final treinosSnap = await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(idAluno)
                  .collection('treinos')
                  .get();
              for (var doc in treinosSnap.docs) {
                await doc.reference.delete();
              }

              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(idAluno)
                  .delete();

              if (_alunoSelecionadoId == idAluno) {
                setState(() {
                  _alunoSelecionadoId = null;
                  _alunoSelecionadoNome = null;
                  _alunoSelecionadoEmail = null;
                });
              } else {
                setState(() {});
              }

              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Aluno removido do sistema! 🗑️'),
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
    String clientID,
    String clientName,
    Map<String, dynamic> currentData,
  ) {
    _planoSelecionadoAluno = currentData['plano'] ?? 'Mensal';
    _mensalidadeController.text =
        (currentData['valorMensalidade'] ??
                currentData['valor'] ??
                currentData['mensalidade'] ??
                _valoresPlanosCarregados[_planoSelecionadoAluno])
            .toString();
    _vencimentoController.text = (currentData['diaVencimento'] ?? 10)
        .toString();
    _statusPagamentoSelecionado = currentData['statusPagamento'] ?? 'Pendente';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          title: Text('Financeiro: $clientName'),
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
                    .doc(clientID)
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

  void _salvarNovaCargaHistorico(String nomeExercicio, String novaCarga) async {
    if (novaCarga.trim().isEmpty || _alunoSelecionadoId == null) return;

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_alunoSelecionadoId)
        .collection('historico_cargas')
        .add({
          'exercicio': nomeExercicio,
          'carga': '$novaCarga kg',
          'dataAnotacao': FieldValue.serverTimestamp(),
        });

    _anotarCargaController.clear();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nova carga registrada com sucesso! 💪'),
        backgroundColor: Colors.green,
      ),
    );
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
          'celular': _novoCelularController.text.trim().isEmpty
              ? '---'
              : _novoCelularController.text.trim(),
          'fotoBase64': _fotoBase64NovaMatricula ?? '---',
        });
      }

      _novoNomeController.clear();
      _novoEmailController.clear();
      _novaSenhaController.clear();
      _novoCelularController.clear();
      setState(() {
        _fotoBase64NovaMatricula = null;
      });

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

  void _abrirPopupCopilotoIA(List<String> bibliotecaExercicios) {
    String objetivoSelecionado = 'Hipertrofia';
    String nivelSelecionado = 'Intermediário';
    String resultadoIA = '';
    bool processandoIA = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.psychology, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Copiloto IA: Montar Ficha',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Defina o perfil do aluno para o Gemini sugerir a ficha:',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: objetivoSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Objetivo Principal',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Hipertrofia',
                            'Emagrecimento / Definição',
                            'Resistência Muscular',
                            'Força Máxima',
                          ]
                          .map(
                            (o) => DropdownMenuItem(value: o, child: Text(o)),
                          )
                          .toList(),
                  onChanged: (v) =>
                      setPopupState(() => objetivoSelecionado = v!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: nivelSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Nível Atual',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Iniciante', 'Intermediário', 'Avançado']
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) => setPopupState(() => nivelSelecionado = v!),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(40),
                  ),
                  onPressed: processandoIA
                      ? null
                      : () async {
                          setPopupState(() => processandoIA = true);
                          final resposta = await _aiService.gerarSugestaoTreino(
                            objetivo: objetivoSelecionado,
                            nivel: nivelSelecionado,
                            exerciciosDisponiveis: bibliotecaExercicios,
                          );
                          setPopupState(() {
                            resultadoIA = resposta;
                            processandoIA = false;
                          });
                        },
                  child: processandoIA
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Consultar Gemini IA 🚀',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
                if (resultadoIA.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(),
                  ),
                  const Text(
                    'Sugestão do Copiloto:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Text(
                      resultadoIA,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ],
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
          ],
        ),
      ),
    );
  }

  // REPOSICIONADA: Função de exibição de detalhes (Antigo erro resolvido)
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
              'Carga Base do Professor: ${dados['carga'] ?? '---'}',
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

  // REPOSICIONADA: Função coletora de carga de treino (Antigo erro resolvido)
  void _abrirPopupAnotarCarga(String nomeExercicio) {
    _anotarCargaController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Anotar Carga de Hoje',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercício: $nomeExercicio',
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _anotarCargaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nova Carga (Somente número em kg)',
                border: OutlineInputBorder(),
                suffixText: 'kg',
              ),
            ),
          ],
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
              backgroundColor: Colors.black,
              foregroundColor: Colors.amber,
            ),
            onPressed: () => _salvarNovaCargaHistorico(
              nomeExercicio,
              _anotarCargaController.text,
            ),
            child: const Text('Gravar Peso'),
          ),
        ],
      ),
    );
  }

  void _abrirHistoricoDeCargasDoExercicio(String nomeExercicio) {
    String analiseIA = "Carregando análise inteligente de carga...";
    bool carregouIA = false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Evolução de Força',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              nomeExercicio,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 470,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('usuarios')
                .doc(_alunoSelecionadoId)
                .collection('historico_cargas')
                .where('exercicio', isEqualTo: nomeExercicio)
                .snapshots(),
            builder: (context, snapHist) {
              if (!snapHist.hasData)
                return const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                );

              var logs = snapHist.data!.docs;

              logs.sort((a, b) {
                var tA = (a.data() as Map)['dataAnotacao'] as Timestamp?;
                var tB = (b.data() as Map)['dataAnotacao'] as Timestamp?;
                if (tA == null) return -1;
                if (tB == null) return 1;
                return tA.compareTo(tB);
              });

              if (logs.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma carga anotada para este exercício ainda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                );
              }

              List<String> listaPesosOrdenados = [];
              List<FlSpot> pontosDoGrafico = [];
              double maiorCargaEncontrada = 0.0;

              for (int index = 0; index < logs.length; index++) {
                var dadosLog = logs[index].data() as Map<String, dynamic>;
                String textoCarga = dadosLog['carga'] ?? '0';
                listaPesosOrdenados.add(textoCarga);

                String apenasNumeros = textoCarga.replaceAll(' kg', '').trim();
                double valorNumericoCarga =
                    double.tryParse(apenasNumeros) ?? 0.0;

                if (valorNumericoCarga > maiorCargaEncontrada) {
                  maiorCargaEncontrada = valorNumericoCarga;
                }

                pontosDoGrafico.add(
                  FlSpot(index.toDouble(), valorNumericoCarga),
                );
              }

              if (!carregouIA) {
                carregouIA = true;
                _aiService
                    .analisarProgressaoCarga(
                      nomeExercicio: nomeExercicio,
                      historicoCargas: listaPesosOrdenados,
                    )
                    .then((res) {
                      if (mounted) {
                        (context as Element).markNeedsBuild();
                        analiseIA = res;
                      }
                    });
              }

              var logsExibicaoTexto = List.from(logs.reversed);

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            analiseIA,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 18, top: 10, left: 4),
                    child: SizedBox(
                      height: 140,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          titlesData: const FlTitlesData(
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                              left: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                          ),
                          minX: 0,
                          maxX: logs.length > 1
                              ? (logs.length - 1).toDouble()
                              : 1,
                          minY: 0,
                          maxY: maiorCargaEncontrada > 0
                              ? (maiorCargaEncontrada + 10)
                              : 50,
                          lineBarsData: [
                            LineChartBarData(
                              spots: pontosDoGrafico,
                              isCurved: true,
                              color: Colors.green[600],
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green[600]!.withOpacity(0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: logsExibicaoTexto.length,
                      itemBuilder: (context, idx) {
                        var logData =
                            logsExibicaoTexto[idx].data()
                                as Map<String, dynamic>;
                        String cargaReg = logData['carga'] ?? '---';

                        String dataFormatada = 'Recente';
                        if (logData['dataAnotacao'] != null) {
                          var dataTime = (logData['dataAnotacao'] as Timestamp)
                              .toDate();
                          dataFormatada =
                              '${dataTime.day.toString().padLeft(2, '0')}/${dataTime.month.toString().padLeft(2, '0')} às ${dataTime.hour.toString().padLeft(2, '0')}:${dataTime.minute.toString().padLeft(2, '0')}';
                        }

                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.fitness_center,
                            size: 16,
                            color: Colors.black87,
                          ),
                          title: Text(
                            cargaReg,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            dataFormatada,
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar', style: TextStyle(color: Colors.black)),
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
    setState(() {});
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

  Widget _construirCardValidadeMensalidade(Map<String, dynamic> dados) {
    String status = dados['statusPagamento'] ?? 'Pendente';
    int diaVencimento = dados['diaVencimento'] ?? 10;
    int diaHoje = DateTime.now().day;

    bool estaAtrasado =
        status == 'Atrasado' ||
        (status == 'Pendente' && diaHoje > diaVencimento);
    bool estaPago = status == 'Pago';

    Color colCard = estaPago
        ? Colors.green[700]!
        : (estaAtrasado ? Colors.red[700]! : Colors.orange[700]!);
    IconData icone = estaPago
        ? Icons.check_circle
        : (estaAtrasado ? Icons.warning : Icons.hourglass_empty);

    return Card(
      elevation: 3,
      color: colCard,
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
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
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

  Widget _construirMiniCardFaturamento(String titulo, String valor, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cor.withOpacity(0.35), width: 1),
        ),
        child: Column(
          children: [
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: cor.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: cor,
              ),
            ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _fotoBase64NovaMatricula != null
                            ? CircleAvatar(
                                radius: 36,
                                backgroundImage: MemoryImage(
                                  base64Decode(_fotoBase64NovaMatricula!),
                                ),
                              )
                            : const CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.black12,
                                child: Icon(
                                  Icons.camera_enhance,
                                  color: Colors.black38,
                                ),
                              ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.amber,
                          ),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Tirar Foto Agora'),
                          onPressed: () async {
                            await _tirarFotoNaHora(false);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: _novoCelularController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Celular/WhatsApp',
                        hintText: '(11) 99999-9999',
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
          'Lista de Alunos Cadastrados:',
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

                String celularAluno = dados['celular'] ?? '---';
                String fotoSalvaMemory = dados['fotoBase64'] ?? '---';

                return Card(
                  color: selecionado ? Colors.amber[100] : Colors.white,
                  child: ListTile(
                    leading:
                        fotoSalvaMemory != '---' && fotoSalvaMemory.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: MemoryImage(
                              base64Decode(fotoSalvaMemory),
                            ),
                            backgroundColor: Colors.black,
                          )
                        : CircleAvatar(
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
                      'Tel: $celularAluno | Vence dia: ${dados['diaVencimento'] ?? 10}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueGrey,
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _alunoSelecionadoId = doc.id;
                              _alunoSelecionadoNome = dados['nome'];
                              _alunoSelecionadoEmail = dados['email'];
                            });
                            _abrirEdicaoDadosAluno(dados);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                            size: 24,
                          ),
                          onPressed: () {
                            _confirmarExclusaoAluno(
                              doc.id,
                              dados['nome'] ?? 'Aluno',
                            );
                          },
                        ),
                        if (selecionado)
                          const Icon(Icons.check_circle, color: Colors.black),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _alunoSelecionadoId = doc.id;
                        _alunoSelecionadoNome = dados['nome'];
                        _alunoSelecionadoEmail = dados['email'];
                        _exercicioSelecionadoCardapio = null;
                      });
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

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('exercicios')
                .snapshots(),
            builder: (context, snapGlobalEx) {
              List<String> exerciciosTexto = [];
              if (snapGlobalEx.hasData) {
                exerciciosTexto = snapGlobalEx.data!.docs
                    .map((e) => (e.data() as Map)['nome'].toString())
                    .toList();
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Treino de: $_alunoSelecionadoNome',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text(
                      'Copiloto IA ✨',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _abrirPopupCopilotoIA(exerciciosTexto),
                  ),
                ],
              );
            },
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
      builder: (context, snapshot) {
        double faturamentoPago = 0.0;
        double faturamentoPendente = 0.0;
        double faturamentoAtrasado = 0.0;
        List<QueryDocumentSnapshot> alunosFiltrados = [];

        if (snapshot.hasData && snapshot.data != null) {
          for (var doc in snapshot.data!.docs) {
            var d = doc.data() as Map<String, dynamic>?;
            if (d == null) continue;

            String cargo = (d['cargo'] ?? 'aluno')
                .toString()
                .toLowerCase()
                .trim();
            if (cargo == 'aluno') {
              alunosFiltrados.add(doc);

              double valor = 0.0;
              if (d['valorMensalidade'] != null) {
                valor =
                    double.tryParse(d['valorMensalidade'].toString()) ?? 0.0;
              } else if (d['valor'] != null) {
                valor = double.tryParse(d['valor'].toString()) ?? 0.0;
              } else if (d['mensalidade'] != null) {
                valor = double.tryParse(d['mensalidade'].toString()) ?? 0.0;
              }

              String status = (d['statusPagamento'] ?? 'Pendente')
                  .toString()
                  .trim();
              int diaVencimento =
                  int.tryParse(d['diaVencimento'].toString()) ?? 10;
              int diaHoje = DateTime.now().day;

              if (status.toLowerCase() == 'pago') {
                faturamentoPago += valor;
              } else if (status.toLowerCase() == 'atrasado' ||
                  (status.toLowerCase() == 'pendente' &&
                      diaHoje > diaVencimento)) {
                faturamentoAtrasado += valor;
              } else {
                faturamentoPendente += valor;
              }
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumo Financeiro Mensal',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _construirMiniCardFaturamento(
                          'Arrecadado',
                          'R\$ ${faturamentoPago.toStringAsFixed(2)}',
                          Colors.green[700]!,
                        ),
                        const SizedBox(width: 8),
                        _construirMiniCardFaturamento(
                          'A Receber',
                          'R\$ ${faturamentoPendente.toStringAsFixed(2)}',
                          Colors.orange[700]!,
                        ),
                        const SizedBox(width: 8),
                        _construirMiniCardFaturamento(
                          'Inadimplente',
                          'R\$ ${faturamentoAtrasado.toStringAsFixed(2)}',
                          Colors.red[700]!,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Status de Mensalidades Individuais',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.black),
                  onPressed: _abrirConfiguracaoDeValoresDoCardapio,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (alunosFiltrados.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text('Nenhum aluno ativo para faturamento.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: alunosFiltrados.length,
                itemBuilder: (context, index) {
                  var doc = alunosFiltrados[index];
                  var dados = doc.data() as Map<String, dynamic>;
                  String status = dados['statusPagamento'] ?? 'Pendente';
                  int diaVencimento = dados['diaVencimento'] ?? 10;
                  int diaHoje = DateTime.now().day;

                  if (status == 'Pendente' && diaHoje > diaVencimento) {
                    status = 'Atrasado';
                  }

                  double valorExibicao =
                      double.tryParse(
                        (dados['valorMensalidade'] ??
                                dados['valor'] ??
                                dados['mensalidade'] ??
                                0)
                            .toString(),
                      ) ??
                      0.0;

                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      title: Text(
                        dados['nome'] ?? 'Aluno',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Plano: ${dados['plano'] ?? 'Mensal'} | Valor: R\$ ${valorExibicao.toStringAsFixed(2)}',
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
              ),
          ],
        );
      },
    );
  }

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
                  _construirBarraPainelCronometro(),
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
              _eProfessor ? 'Ficha Ativa:' : 'Escolha a Série de Hoje:',
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
                String nomeDoExercicioItem =
                    dadosTratados['exercicios'] ?? 'Exercício';

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
                                    nomeDoExercicioItem,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${dadosTratados['grupo'] ?? ''} | Reps: ${dadosTratados['series'] ?? ''} | Base: ${dadosTratados['carga'] ?? ''}',
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.history,
                                color: Colors.blueGrey,
                                size: 22,
                              ),
                              tooltip: 'Ver Evolução de Força',
                              onPressed: () =>
                                  _abrirHistoricoDeCargasDoExercicio(
                                    nomeDoExercicioItem,
                                  ),
                            ),
                            if (_eProfessor) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                  size: 22,
                                ),
                                onPressed: () => _abrirConfiguracaoExercicio(
                                  dadosTratados['grupo'] ?? '',
                                  nomeDoExercicioItem,
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
                            ] else ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.scale,
                                  color: Colors.green,
                                  size: 22,
                                ),
                                tooltip: 'Anotar Peso de Hoje',
                                onPressed: () =>
                                    _abrirPopupAnotarCarga(nomeDoExercicioItem),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.amber,
                                  size: 24,
                                ),
                                tooltip: 'Iniciar Descanso',
                                onPressed: () => _iniciarCronometroDescanso(
                                  nomeDoExercicioItem,
                                ),
                              ),
                            ],
                          ],
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
