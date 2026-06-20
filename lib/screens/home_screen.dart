import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';
import '../services/ai_service.dart';
import '../screens/treinos_padrao_page.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _versaoCodigoAtual = '1.0.2';
  bool _aplicativoDesatualizado = false;
  String _linkDownloadNovoApk = '---';

  // Controles de Texto
  final _grupoController = TextEditingController();
  final _seriesController = TextEditingController();
  final _cargaController = TextEditingController();
  final _novoNomeController = TextEditingController();
  final _novoEmailController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _novoExercicioCardapioController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _novoCellularController = TextEditingController();

  String? _fotoBase64NovaMatricula;
  String? _fotoBase64Edicao;

  final _profNomeController = TextEditingController();
  final _profEmailController = TextEditingController();
  final _profSenhaController = TextEditingController();

  final _mensalidadeController = TextEditingController();
  final _vencimentoController = TextEditingController();
  String _statusPagamentoSelecionado = 'Pendente';
  String _planoSelecionadoAluno = 'Mensal';

  final _editMensalController = TextEditingController();
  final _editTrimestralController = TextEditingController();
  final _editSemestralController = TextEditingController();
  final _editAnual = TextEditingController();

  final _editarNomeAlunoController = TextEditingController();
  final _editarEmailAlunoController = TextEditingController();
  final _editarCellularAlunoController = TextEditingController();

  final _anotarCargaController = TextEditingController();
  final _avaliacaoPesoController = TextEditingController();
  final _avaliacaoAlturaController = TextEditingController();
  final _avaliacaoGorduraController = TextEditingController();
  final _avaliacaoMassaMagraController = TextEditingController();
  final _avaliacaoCinturaController = TextEditingController();
  final _avaliacaoAbdomenController = TextEditingController();
  final _avaliacaoQuadrilController = TextEditingController();
  final _avaliacaoPeitoralController = TextEditingController();
  final _avaliacaoBracoDireitoController = TextEditingController();
  final _avaliacaoBracoEsquerdoController = TextEditingController();
  final _avaliacaoCoxaDireitaController = TextEditingController();
  final _avaliacaoCoxaEsquerdaController = TextEditingController();
  final _avaliacaoPanturrilhaDireitaController = TextEditingController();
  final _avaliacaoPanturrilhaEsquerdaController = TextEditingController();
  final _avaliacaoObservacoesController = TextEditingController();

  Timer? _descansoTimer;
  int _tempoRestanteSegundos = 60;
  int _tempoDefinidoPadrao = 60;
  bool _cronometroAtivo = false;
  String _exercicioEmDescanso = '';

  String _filtroBuscaAlunos = '';
  String? _exercicioSelecionadoCardapio;
  String _grupoSelecionadoFiltro = 'Peito';

  Map<String, double> _valoresPlanosCarregados = {
    'Peito': 80.0,
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

  bool _eProfessor = false;
  bool _eAdminGeral = false;
  bool _carregandoPerfil = true;

  String _fichaSelecionadaAluno = 'A';
  Future<Map<String, dynamic>?>? _futureTreinosAntigos;
  String? _alunoIdCacheTreinosAntigos;
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
    _ouvirValoresDoCardapioDePlanosETravaVersao();
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
        final docRef = snap.docs.first;
        final dadosUsuario = docRef.data();

        String cargo = (dadosUsuario['cargo'] ?? '').toString().toLowerCase().trim();
        final bool legacyEProfessor = dadosUsuario['eProfessor'] == true;

        if (cargo.isEmpty) {
          cargo = legacyEProfessor ? 'professor' : 'aluno';
        }

        if (cargo == 'admin') {
          setState(() {
            _eAdminGeral = true;
            _eProfessor = true;
            _alunoSelecionadoId = null;
            _carregandoPerfil = false;
          });
        } else if (cargo == 'professor') {
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
            _alunoSelecionadoId = docRef.id;
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

  void _ouvirValoresDoCardapioDePlanosETravaVersao() {
    FirebaseFirestore.instance
        .collection('configuracoes')
        .doc('planos')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final dados = snapshot.data()!;

            String versaoObrigatoriaBanco =
                dados['versao_obrigatoria']?.toString() ?? '1.0.2';
            String linkApk =
                dados['url_download_apk']?.toString() ?? 'https://codemagic.io';

            setState(() {
              _valoresPlanosCarregados = {
                'Peito': 80.0,
                'Mensal': double.tryParse(dados['Mensal'].toString()) ?? 80.0,
                'Trimestral':
                    double.tryParse(dados['Trimestral'].toString()) ?? 220.0,
                'Semestral':
                    double.tryParse(dados['Semestral'].toString()) ?? 420.0,
                'Anual': double.tryParse(dados['Anual'].toString()) ?? 800.0,
              };
              _linkDownloadNovoApk = linkApk;

              if (versaoObrigatoriaBanco != _versaoCodigoAtual) {
                _aplicativoDesatualizado = true;
              } else {
                _aplicativoDesatualizado = false;
              }
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

    if (_profSenhaController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A senha do professor deve conter pelo menos 6 caracteres! ❌',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'TemporaryProfApp',
        options: Firebase.app().options,
      );

      FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      UserCredential userCred = await tempAuth.createUserWithEmailAndPassword(
        email: _profEmailController.text.trim(),
        password: _profSenhaController.text.trim(),
      );

      String novoUid = userCred.user!.uid;

      await FirebaseFirestore.instance.collection('usuarios').doc(novoUid).set({
        'nome': _profNomeController.text.trim(),
        'email': _profEmailController.text.trim(),
        'cargo': 'professor',
        'criadoEm': FieldValue.serverTimestamp(),
      });

      await tempApp.delete();

      _profNomeController.clear();
      _profEmailController.clear();
      _profSenhaController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Professor credenciado com sucesso! O Admin permanece ativo. 🛡️',
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao cadastrar professor.';
      if (e.code == 'weak-password') {
        mensagem = 'A senha digitada é muito fraca. Mínimo de 6 caracteres.';
      } else if (e.code == 'email-already-in-use') {
        mensagem = 'Este e-mail já está em uso por outro usuário.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      print("Erro ao cadastrar professor: $e");
    }
  }

  void _abrirEdicaoProfessor(String professorId, Map<String, dynamic> dados) {
    final nomeEditController = TextEditingController(
      text: (dados['nome'] ?? '').toString(),
    );
    final emailEditController = TextEditingController(
      text: (dados['email'] ?? '').toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Editar Professor',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeEditController,
              decoration: const InputDecoration(
                labelText: 'Nome do Professor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailEditController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail do Professor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A senha de login não é alterada aqui. Para trocar senha, use recuperação de senha ou uma função administrativa específica.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.amber,
            ),
            icon: const Icon(Icons.save),
            label: const Text('Salvar'),
            onPressed: () async {
              final nome = nomeEditController.text.trim();
              final email = emailEditController.text.trim();

              if (nome.isEmpty || email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informe nome e e-mail do professor.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(professorId)
                  .set({
                    'nome': nome,
                    'email': email,
                    'cargo': 'professor',
                    'atualizadoEm': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Professor atualizado com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmarExclusaoProfessor(String professorId, String nomeProfessor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Excluir Professor?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Tem certeza que deseja remover "$nomeProfessor" da lista de professores?\n\nAtenção: isso remove o cadastro no Firestore. O login no Firebase Authentication só pode ser removido com uma função administrativa específica.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete),
            label: const Text('Excluir'),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(professorId)
                  .delete();

              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Professor removido da lista.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
          ),
        ],
      ),
    );
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
                    .where((k) => k != 'Peito')
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
        content: Text('Exercício saved na biblioteca! ✔'),
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

  double _converterNumeroAvaliacao(String valor) {
    final textoLimpo = valor.trim().replaceAll(',', '.');
    return double.tryParse(textoLimpo) ?? 0.0;
  }

  String _formatarDataAvaliacao(dynamic timestamp) {
    if (timestamp == null || timestamp is! Timestamp) {
      return 'Data não registrada';
    }

    final data = timestamp.toDate();
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$ano às $hora:$minuto';
  }

  Widget _campoNumeroAvaliacao({
    required String label,
    required TextEditingController controller,
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void _limparCamposAvaliacaoFisica() {
    _avaliacaoPesoController.clear();
    _avaliacaoAlturaController.clear();
    _avaliacaoGorduraController.clear();
    _avaliacaoMassaMagraController.clear();
    _avaliacaoCinturaController.clear();
    _avaliacaoAbdomenController.clear();
    _avaliacaoQuadrilController.clear();
    _avaliacaoPeitoralController.clear();
    _avaliacaoBracoDireitoController.clear();
    _avaliacaoBracoEsquerdoController.clear();
    _avaliacaoCoxaDireitaController.clear();
    _avaliacaoCoxaEsquerdaController.clear();
    _avaliacaoPanturrilhaDireitaController.clear();
    _avaliacaoPanturrilhaEsquerdaController.clear();
    _avaliacaoObservacoesController.clear();
  }

  void _abrirPopupNovaAvaliacaoFisica() {
    if (_alunoSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um aluno antes de cadastrar a avaliação.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _limparCamposAvaliacaoFisica();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.monitor_weight, color: Colors.deepPurple),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nova Avaliação Física',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
                Text(
                  'Aluno: ${_alunoSelecionadoNome ?? 'Aluno selecionado'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Dados principais',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _campoNumeroAvaliacao(
                  label: 'Peso corporal',
                  controller: _avaliacaoPesoController,
                  suffix: 'kg',
                ),
                _campoNumeroAvaliacao(
                  label: 'Altura',
                  controller: _avaliacaoAlturaController,
                  suffix: 'm',
                ),
                _campoNumeroAvaliacao(
                  label: 'Gordura corporal',
                  controller: _avaliacaoGorduraController,
                  suffix: '%',
                ),
                _campoNumeroAvaliacao(
                  label: 'Massa magra',
                  controller: _avaliacaoMassaMagraController,
                  suffix: 'kg',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Medidas corporais',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _campoNumeroAvaliacao(
                  label: 'Cintura',
                  controller: _avaliacaoCinturaController,
                  suffix: 'cm',
                ),
                _campoNumeroAvaliacao(
                  label: 'Abdômen',
                  controller: _avaliacaoAbdomenController,
                  suffix: 'cm',
                ),
                _campoNumeroAvaliacao(
                  label: 'Quadril',
                  controller: _avaliacaoQuadrilController,
                  suffix: 'cm',
                ),
                _campoNumeroAvaliacao(
                  label: 'Peitoral',
                  controller: _avaliacaoPeitoralController,
                  suffix: 'cm',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _campoNumeroAvaliacao(
                        label: 'Braço direito',
                        controller: _avaliacaoBracoDireitoController,
                        suffix: 'cm',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _campoNumeroAvaliacao(
                        label: 'Braço esquerdo',
                        controller: _avaliacaoBracoEsquerdoController,
                        suffix: 'cm',
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _campoNumeroAvaliacao(
                        label: 'Coxa direita',
                        controller: _avaliacaoCoxaDireitaController,
                        suffix: 'cm',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _campoNumeroAvaliacao(
                        label: 'Coxa esquerda',
                        controller: _avaliacaoCoxaEsquerdaController,
                        suffix: 'cm',
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _campoNumeroAvaliacao(
                        label: 'Panturrilha direita',
                        controller: _avaliacaoPanturrilhaDireitaController,
                        suffix: 'cm',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _campoNumeroAvaliacao(
                        label: 'Panturrilha esquerda',
                        controller: _avaliacaoPanturrilhaEsquerdaController,
                        suffix: 'cm',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _avaliacaoObservacoesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observações da avaliação',
                    hintText: 'Ex: queixas, objetivo, evolução percebida...',
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.save),
            label: const Text('Salvar Avaliação'),
            onPressed: () => _salvarAvaliacaoFisica(),
          ),
        ],
      ),
    );
  }

  void _salvarAvaliacaoFisica() async {
    if (_alunoSelecionadoId == null) return;

    final peso = _converterNumeroAvaliacao(_avaliacaoPesoController.text);
    final altura = _converterNumeroAvaliacao(_avaliacaoAlturaController.text);
    final imc = altura > 0 ? peso / (altura * altura) : 0.0;

    if (peso <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe pelo menos o peso do aluno para salvar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_alunoSelecionadoId)
        .collection('avaliacoes_fisicas')
        .add({
          'dataAvaliacao': FieldValue.serverTimestamp(),
          'peso': peso,
          'altura': altura,
          'imc': imc,
          'gorduraCorporal': _converterNumeroAvaliacao(
            _avaliacaoGorduraController.text,
          ),
          'massaMagra': _converterNumeroAvaliacao(
            _avaliacaoMassaMagraController.text,
          ),
          'cintura': _converterNumeroAvaliacao(
            _avaliacaoCinturaController.text,
          ),
          'abdomen': _converterNumeroAvaliacao(
            _avaliacaoAbdomenController.text,
          ),
          'quadril': _converterNumeroAvaliacao(
            _avaliacaoQuadrilController.text,
          ),
          'peitoral': _converterNumeroAvaliacao(
            _avaliacaoPeitoralController.text,
          ),
          'bracoDireito': _converterNumeroAvaliacao(
            _avaliacaoBracoDireitoController.text,
          ),
          'bracoEsquerdo': _converterNumeroAvaliacao(
            _avaliacaoBracoEsquerdoController.text,
          ),
          'coxaDireita': _converterNumeroAvaliacao(
            _avaliacaoCoxaDireitaController.text,
          ),
          'coxaEsquerda': _converterNumeroAvaliacao(
            _avaliacaoCoxaEsquerdaController.text,
          ),
          'panturrilhaDireita': _converterNumeroAvaliacao(
            _avaliacaoPanturrilhaDireitaController.text,
          ),
          'panturrilhaEsquerda': _converterNumeroAvaliacao(
            _avaliacaoPanturrilhaEsquerdaController.text,
          ),
          'observacoes': _avaliacaoObservacoesController.text.trim(),
          'alunoNome': _alunoSelecionadoNome ?? 'Aluno',
          'registradoPorUid': _auth.currentUser?.uid ?? '---',
          'registradoPorEmail': _auth.currentUser?.email ?? '---',
          'criadoEm': FieldValue.serverTimestamp(),
        });

    _limparCamposAvaliacaoFisica();

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Avaliação física salva no histórico do aluno! 📊'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _linhaResumoAvaliacao(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _mesReferenciaAtualAvaliacaoFisica() {
    final agora = DateTime.now();
    return '${agora.year}-${agora.month.toString().padLeft(2, '0')}';
  }

  bool _avaliacaoFisicaProAtiva(Map<String, dynamic> dadosAluno) {
    final status =
        (dadosAluno['avaliacaoFisicaStatusAssinatura'] ?? 'NaoAtivado')
            .toString();
    final Timestamp? dataFim =
        dadosAluno['dataFimAvaliacaoFisica'] as Timestamp?;

    if (status != 'Ativo') return false;
    if (dataFim == null) return true;

    return dataFim.toDate().isAfter(DateTime.now());
  }

  bool _comboPerformanceIAAtivo(Map<String, dynamic> dadosAluno) {
    final plano = (dadosAluno['planoAvaliacaoFisica'] ?? '').toString();
    final planoCombo = plano == 'Combo Performance IA';
    return planoCombo && _avaliacaoFisicaProAtiva(dadosAluno);
  }

  int _limiteMensalAnalisesAvaliacaoFisica(Map<String, dynamic> dadosAluno) {
    return _comboPerformanceIAAtivo(dadosAluno) ? 8 : 4;
  }

  int _usosAnaliseAvaliacaoFisicaNoMes(Map<String, dynamic> dadosAluno) {
    final mesAtual = _mesReferenciaAtualAvaliacaoFisica();
    final mesSalvo = (dadosAluno['avaliacaoFisicaIAMesReferencia'] ?? '')
        .toString();
    if (mesSalvo != mesAtual) return 0;
    return int.tryParse(
          (dadosAluno['avaliacaoFisicaIAUsosMes'] ?? 0).toString(),
        ) ??
        0;
  }

  Future<void> _liberarAvaliacaoFisicaProManual({required bool combo}) async {
    if (_alunoSelecionadoId == null) return;

    final agora = DateTime.now();
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_alunoSelecionadoId)
        .set({
          'avaliacaoFisicaStatusAssinatura': 'Ativo',
          'planoAvaliacaoFisica': combo
              ? 'Combo Performance IA'
              : 'Evolução Física PRO',
          'valorAvaliacaoFisica': combo ? 29.90 : 19.90,
          'dataInicioAvaliacaoFisica': FieldValue.serverTimestamp(),
          'dataFimAvaliacaoFisica': Timestamp.fromDate(
            agora.add(const Duration(days: 30)),
          ),
          'avaliacaoFisicaIAMesReferencia':
              _mesReferenciaAtualAvaliacaoFisica(),
          'avaliacaoFisicaIAUsosMes': 0,
          'atualizadoEm': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          combo
              ? 'Combo Performance IA liberado por 30 dias para o aluno!'
              : 'Evolução Física PRO liberada por 30 dias para o aluno!',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _cardBloqueioAvaliacaoFisicaPro({bool professor = false}) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.withOpacity(0.12),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evolução Física PRO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Histórico de avaliações + análise inteligente com IA.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.withOpacity(0.22)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planos disponíveis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Evolução Física PRO: R\$ 19,90/mês — até 4 análises IA por mês.',
                  ),
                  Text(
                    '• Combo Performance IA: R\$ 29,90/mês — Scanner + Evolução Física + até 8 análises IA por mês.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () =>
                        _mostrarPopupCompraAvaliacaoFisicaIA(combo: false),
                    icon: const Icon(Icons.pix, size: 18),
                    label: const Text(
                      'Pagar R\$ 19,90',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () =>
                        _mostrarPopupCompraAvaliacaoFisicaIA(combo: true),
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text(
                      'Combo R\$ 29,90',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              professor
                  ? 'O professor pode gerar o PIX para o aluno. A liberação será automática após confirmação do Mercado Pago.'
                  : 'Pague via PIX para liberar automaticamente seu histórico de evolução física e a análise IA.',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirCardAvaliacaoFisicaProfessor() {
    if (_alunoSelecionadoId == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_alunoSelecionadoId)
          .snapshots(),
      builder: (context, snapAluno) {
        if (!snapAluno.hasData || !snapAluno.data!.exists) {
          return const SizedBox();
        }

        final dadosAluno = snapAluno.data!.data() as Map<String, dynamic>;
        final proAtivo = _avaliacaoFisicaProAtiva(dadosAluno);
        final plano = (dadosAluno['planoAvaliacaoFisica'] ?? 'Não contratado')
            .toString();
        final limiteIA = _limiteMensalAnalisesAvaliacaoFisica(dadosAluno);
        final usosIA = _usosAnaliseAvaliacaoFisicaNoMes(dadosAluno);

        return Card(
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            leading: const Icon(Icons.assignment_ind, color: Colors.deepPurple),
            title: const Text(
              'Histórico do Aluno / Avaliação Física',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              proAtivo
                  ? 'Plano ativo: $plano | IA: $usosIA/$limiteIA no mês'
                  : 'Professor pode cadastrar avaliações. IA/visualização PRO dependem do plano.',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: proAtivo
                            ? Colors.green.withOpacity(0.08)
                            : Colors.orange.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: proAtivo
                              ? Colors.green.withOpacity(0.25)
                              : Colors.orange.withOpacity(0.35),
                        ),
                      ),
                      child: Text(
                        proAtivo
                            ? '✅ $plano ativo. Limite mensal de análises IA: $usosIA/$limiteIA.'
                            : '⚠️ Plano PRO ainda não ativo para o aluno. O professor pode cadastrar as avaliações físicas normalmente. A análise com IA e a visualização PRO ficam liberadas após pagamento.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(42),
                      ),
                      onPressed: _abrirPopupNovaAvaliacaoFisica,
                      icon: const Icon(Icons.add_chart),
                      label: const Text(
                        'Cadastrar Nova Avaliação Física',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: proAtivo
                            ? Colors.deepPurple
                            : Colors.grey,
                        side: BorderSide(
                          color: proAtivo ? Colors.deepPurple : Colors.grey,
                        ),
                        minimumSize: const Size.fromHeight(42),
                      ),
                      onPressed: proAtivo
                          ? _abrirPopupAnaliseAvaliacaoFisicaIA
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Para usar a análise com IA, ative a Evolução Física PRO ou o Combo Performance IA para este aluno.',
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            },
                      icon: Icon(proAtivo ? Icons.psychology : Icons.lock),
                      label: Text(
                        proAtivo
                            ? 'Analisar evolução com IA'
                            : 'Análise IA bloqueada - ativar plano PRO',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!proAtivo) ...[
                      const SizedBox(height: 12),
                      _cardBloqueioAvaliacaoFisicaPro(professor: true),
                    ],
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(_alunoSelecionadoId)
                          .collection('avaliacoes_fisicas')
                          .orderBy('dataAvaliacao', descending: true)
                          .snapshots(),
                      builder: (context, snapAvaliacoes) {
                        if (!snapAvaliacoes.hasData) {
                          return const LinearProgressIndicator(
                            color: Colors.deepPurple,
                          );
                        }

                        final avaliacoes = snapAvaliacoes.data!.docs;

                        if (avaliacoes.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Nenhuma avaliação física cadastrada para este aluno ainda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }

                        final ultima =
                            avaliacoes.first.data() as Map<String, dynamic>;
                        final dataUltima = _formatarDataAvaliacao(
                          ultima['dataAvaliacao'],
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.deepPurple.withOpacity(0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Última avaliação: $dataUltima',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _linhaResumoAvaliacao(
                                    'Peso',
                                    '${(ultima['peso'] ?? 0).toString()} kg',
                                  ),
                                  _linhaResumoAvaliacao(
                                    'IMC',
                                    '${double.tryParse((ultima['imc'] ?? 0).toString())?.toStringAsFixed(1) ?? '0.0'}',
                                  ),
                                  _linhaResumoAvaliacao(
                                    'Gordura corporal',
                                    '${(ultima['gorduraCorporal'] ?? 0).toString()}%',
                                  ),
                                  _linhaResumoAvaliacao(
                                    'Cintura',
                                    '${(ultima['cintura'] ?? 0).toString()} cm',
                                  ),
                                  if ((ultima['observacoes'] ?? '')
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Observações: ${ultima['observacoes']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Histórico cadastrado',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: avaliacoes.length > 5
                                  ? 5
                                  : avaliacoes.length,
                              itemBuilder: (context, index) {
                                final dados =
                                    avaliacoes[index].data()
                                        as Map<String, dynamic>;
                                final data = _formatarDataAvaliacao(
                                  dados['dataAvaliacao'],
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Peso: ${dados['peso'] ?? 0} kg | Gordura: ${dados['gorduraCorporal'] ?? 0}% | Cintura: ${dados['cintura'] ?? 0} cm',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirPopupAnaliseAvaliacaoFisicaIA() async {
    if (_alunoSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um aluno para a IA analisar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final alunoDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_alunoSelecionadoId)
        .get();

    final dadosAlunoAssinatura = alunoDoc.data() ?? <String, dynamic>{};
    if (!_avaliacaoFisicaProAtiva(dadosAlunoAssinatura)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evolução Física PRO não está ativa para este aluno.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final limiteIA = _limiteMensalAnalisesAvaliacaoFisica(dadosAlunoAssinatura);
    final usosIA = _usosAnaliseAvaliacaoFisicaNoMes(dadosAlunoAssinatura);

    if (usosIA >= limiteIA) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Limite mensal de análises IA atingido: $usosIA/$limiteIA.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'IA analisando o histórico físico do aluno...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_alunoSelecionadoId)
          .collection('avaliacoes_fisicas')
          .orderBy('dataAvaliacao', descending: true)
          .limit(12)
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este aluno ainda não possui avaliações físicas cadastradas.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final avaliacoesDesc = snap.docs;
      final avaliacoesCronologicas = avaliacoesDesc.reversed.toList();
      final primeira = avaliacoesCronologicas.first.data();
      final ultima = avaliacoesCronologicas.last.data();

      String valorCampo(
        Map<String, dynamic> dados,
        String campo,
        String unidade,
      ) {
        final valor = dados[campo];
        if (valor == null) return '0$unidade';
        final numero = double.tryParse(valor.toString()) ?? 0.0;
        if (numero == 0) return '0$unidade';
        return '${numero.toStringAsFixed(numero.truncateToDouble() == numero ? 0 : 1)}$unidade';
      }

      double numeroCampo(Map<String, dynamic> dados, String campo) {
        return double.tryParse((dados[campo] ?? 0).toString()) ?? 0.0;
      }

      String diferencaCampo(String titulo, String campo, String unidade) {
        final inicial = numeroCampo(primeira, campo);
        final atual = numeroCampo(ultima, campo);
        final diff = atual - inicial;
        final sinal = diff > 0 ? '+' : '';
        return '$titulo: inicial ${inicial.toStringAsFixed(1)}$unidade, atual ${atual.toStringAsFixed(1)}$unidade, diferença $sinal${diff.toStringAsFixed(1)}$unidade';
      }

      final linhasHistorico = avaliacoesCronologicas
          .map((doc) {
            final dados = doc.data();
            return '- ${_formatarDataAvaliacao(dados['dataAvaliacao'])}: '
                'peso ${valorCampo(dados, 'peso', ' kg')}, '
                'IMC ${valorCampo(dados, 'imc', '')}, '
                'gordura ${valorCampo(dados, 'gorduraCorporal', '%')}, '
                'massa magra ${valorCampo(dados, 'massaMagra', ' kg')}, '
                'cintura ${valorCampo(dados, 'cintura', ' cm')}, '
                'abdômen ${valorCampo(dados, 'abdomen', ' cm')}, '
                'quadril ${valorCampo(dados, 'quadril', ' cm')}. '
                'Observações: ${(dados['observacoes'] ?? '').toString().trim()}';
          })
          .join('\n');

      final resumoNumerico = [
        diferencaCampo('Peso', 'peso', ' kg'),
        diferencaCampo('Gordura corporal', 'gorduraCorporal', '%'),
        diferencaCampo('Massa magra', 'massaMagra', ' kg'),
        diferencaCampo('Cintura', 'cintura', ' cm'),
        diferencaCampo('Abdômen', 'abdomen', ' cm'),
        diferencaCampo('Quadril', 'quadril', ' cm'),
      ].join('\n');

      final promptAnalise =
          '''
NÃO crie ficha de treino. NÃO invente dados. Você é uma inteligência de apoio ao professor de academia.
Analise o histórico de avaliação física do aluno ${_alunoSelecionadoNome ?? 'selecionado'}.
Use somente os dados abaixo e gere um resumo profissional, objetivo e fácil de entender.

O resumo deve conter:
1. Resumo geral da evolução.
2. Pontos positivos.
3. Pontos de atenção.
4. Possível interpretação dos dados sem diagnóstico médico.
5. Sugestão prática para o professor acompanhar o aluno nas próximas semanas.
6. Uma mensagem curta que o professor poderia falar ao aluno.

Regras:
- Não faça diagnóstico médico.
- Não prometa resultado.
- Se algum campo estiver zerado ou ausente, diga que precisa de mais dados para análise daquele ponto.
- Use linguagem profissional e motivadora.

Resumo numérico comparando primeira e última avaliação:
$resumoNumerico

Histórico completo utilizado:
$linhasHistorico
''';

      final respostaIA = await _aiService.gerarSugestaoTreino(
        objetivo: promptAnalise,
        nivel: 'análise de avaliação física, sem montar treino',
        exerciciosDisponiveis: const [
          'Não montar treino. Apenas analisar histórico físico do aluno.',
        ],
      );

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_alunoSelecionadoId)
          .collection('analises_ia_avaliacao_fisica')
          .add({
            'resumo': respostaIA,
            'alunoNome': _alunoSelecionadoNome ?? 'Aluno',
            'quantidadeAvaliacoesUtilizadas': avaliacoesDesc.length,
            'historicoUtilizado': linhasHistorico,
            'criadoEm': FieldValue.serverTimestamp(),
            'professorUid': _auth.currentUser?.uid ?? '---',
            'professorEmail': _auth.currentUser?.email ?? '---',
          });

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_alunoSelecionadoId)
          .set({
            'avaliacaoFisicaIAMesReferencia':
                _mesReferenciaAtualAvaliacaoFisica(),
            'avaliacaoFisicaIAUsosMes': usosIA + 1,
            'ultimaAnaliseAvaliacaoFisicaEm': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);

      if (respostaIA.startsWith('ERRO_429') || respostaIA.contains('RESOURCE_EXHAUSTED')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Serviço de IA temporariamente indisponível por limite de uso. Verifique os créditos da API ou tente novamente mais tarde.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 8),
          ),
        );
        return;
      }

      if (respostaIA.startsWith('ERRO_')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha na análise IA: $respostaIA'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.psychology, color: Colors.deepPurple),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Análise IA da Evolução',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                respostaIA,
                style: const TextStyle(fontSize: 13, height: 1.35),
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
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao analisar evolução com IA: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _matricularNovoAluno() async {
    if (_novoNomeController.text.isEmpty ||
        _novoEmailController.text.isEmpty ||
        _novaSenhaController.text.isEmpty)
      return;

    if (_novaSenhaController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A senha do aluno deve conter pelo menos 6 caracteres! ❌',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'TemporaryStudentApp',
        options: Firebase.app().options,
      );

      FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      UserCredential userCred = await tempAuth.createUserWithEmailAndPassword(
        email: _novoEmailController.text.trim(),
        password: _novaSenhaController.text.trim(),
      );

      String novoUidDoAluno = userCred.user!.uid;

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(novoUidDoAluno)
          .set({
            'nome': _novoNomeController.text.trim(),
            'email': _novoEmailController.text.trim(),
            'cargo': 'aluno',
            'statusPagamento': 'Pendente',
            'diaVencimento': 10,
            'plano': 'Mensal',
            'valorMensalidade': 80.0,
            'celular': _novoCellularController.text.trim().isEmpty
                ? '---'
                : _novoCellularController.text.trim(),
            'iaStatusAssinatura': 'NaoAtivado',
            'criadoEm': FieldValue.serverTimestamp(),
          });

      await tempApp.delete();

      _novoNomeController.clear();
      _novoEmailController.clear();
      _novaSenhaController.clear();
      _novoCellularController.clear();
      setState(() {
        _fotoBase64NovaMatricula = null;
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aluno matriculado com sucesso! Painel do professor permanece intacto. 🚀',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Erro no cadastro do aluno.';
      if (e.code == 'weak-password') {
        msg = 'Senha fraca! Escolha uma senha com 6 ou mais dígitos.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'O e-mail informado já está em uso.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      print("Erro ao cadastrar aluno: $e");
    }
  }

  void _abrirPopupCopilotoIA(List<String> bibliotecaExercicios) {
    String objetivoSelecionado = 'Hipertrofia';
    String nivelSelecionado = 'Intermediário';
    String resultadoIA = '';
    bool processandoIA = false;
    bool gravandoNoBanco = false;

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
                  onPressed: processandoIA || gravandoNoBanco
                      ? null
                      : () async {
                          setPopupState(() => processandoIA = true);

                          String diretrizMetodologica =
                              "DIRETRIZ OBRIGATÓRIA DA ACADEMIA:\n"
                              "- Se gerar treinos para a ficha 'A', use APENAS exercícios de Peito e Tríceps.\n"
                              "- Se gerar treinos para a ficha 'B', use APENAS exercícios de Pernas.\n"
                              "- Se gerar treinos para a ficha 'C', use APENAS exercícios de Costas e Bíceps.\n"
                              "- Se gerar treinos para a ficha 'D', use APENAS exercícios de Ombros.\n"
                              "Distribua os exercícios disponíveis inteligentemente seguindo essa matriz exata.";

                          final resposta = await _aiService.gerarSugestaoTreino(
                            objetivo:
                                '$objetivoSelecionado ($diretrizMetodologica. ATENÇÃO: Devolva a resposta estritamente formatada em JSON válido. O formato deve ser uma lista de objetos contendo as chaves: "ficha", "grupo", "exercicio", "series", "carga".)',
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
                    'Sugestão Estruturada da IA:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        resultadoIA,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    icon: gravandoNoBanco
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.playlist_add_check),
                    label: Text(
                      gravandoNoBanco
                          ? 'Gravando na Grade...'
                          : 'Injetar Exercícios na Ficha do Aluno 🔥',
                    ),
                    onPressed: gravandoNoBanco || _alunoSelecionadoId == null
                        ? null
                        : () async {
                            setPopupState(() => gravandoNoBanco = true);
                            try {
                              // CORREÇÃO DA SINTAXE QUE ESTAVA QUEBRADA NA COMPILAÇÃO ANTERIOR
                              String limpandoJson = resultadoIA
                                  .replaceAll('```json', '')
                                  .replaceAll('```', '')
                                  .trim();
                              final List<dynamic> listaExerciciosIA =
                                  jsonDecode(limpandoJson);

                              for (var exercicioItem in listaExerciciosIA) {
                                String letraFicha =
                                    (exercicioItem['ficha'] ??
                                            _fichaSelecionadaAluno)
                                        .toString()
                                        .toUpperCase()
                                        .trim();
                                String grupoMusc =
                                    exercicioItem['grupo'] ?? 'Geral';
                                String nomeEx =
                                    exercicioItem['exercicio'] ?? 'Exercício';
                                String reps = exercicioItem['series'] ?? '4x10';
                                String peso = exercicioItem['carga'] ?? '---';

                                await _workoutService.salvarTreino(
                                  alunoId: _alunoSelecionadoId!,
                                  ficha: letraFicha,
                                  grupoMuscular: grupoMusc,
                                  nomeExercicios: nomeEx,
                                  seriesRepeticoes: reps,
                                  carga: peso.contains('kg')
                                      ? peso
                                      : '$peso kg',
                                  videoUrl: '---',
                                );
                              }

                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Ficha Inteligente de $_alunoSelecionadoNome montada com sucesso! 🏋️‍♂️💪',
                                  ),
                                  backgroundColor: Colors.green[800],
                                ),
                              );
                            } catch (erroParsing) {
                              print(
                                "Erro ao processar estrutura JSON da IA: $erroParsing",
                              );
                              setPopupState(() => gravandoNoBanco = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Falha ao processar o formato gerado. Tente consultar novamente.',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
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

  void _injetarPlanoTreinoPadrao(String nivel) async {
    if (_alunoSelecionadoId == null) return;

    List<Map<String, String>> planoModelo = [];

    if (nivel == 'Iniciante') {
      planoModelo = [
        {
          'ficha': 'A',
          'grupo': 'Peito',
          'exercicio': 'Supino Reto na Máquina',
          'series': '3x12',
          'carga': '20 kg',
        },
        {
          'ficha': 'A',
          'grupo': 'Peito',
          'exercicio': 'Pec Deck (Voador)',
          'series': '3x12',
          'carga': '25 kg',
        },
        {
          'ficha': 'A',
          'grupo': 'Tríceps',
          'exercicio': 'Tríceps Pulley',
          'series': '3x12',
          'carga': '15 kg',
        },
        {
          'ficha': 'B',
          'grupo': 'Pernas',
          'exercicio': 'Leg Press 45º',
          'series': '3x15',
          'carga': '60 kg',
        },
        {
          'ficha': 'B',
          'grupo': 'Pernas',
          'exercicio': 'Cadeira Extensora',
          'series': '3x12',
          'carga': '20 kg',
        },
        {
          'ficha': 'C',
          'grupo': 'Costas',
          'exercicio': 'Puxada Aberta no Pulley',
          'series': '3x12',
          'carga': '25 kg',
        },
        {
          'ficha': 'C',
          'grupo': 'Bíceps',
          'exercicio': 'Rosca Direta com Halteres',
          'series': '3x12',
          'carga': '6 kg',
        },
      ];
    } else if (nivel == 'Intermediário') {
      planoModelo = [
        {
          'ficha': 'A',
          'grupo': 'Peito',
          'exercicio': 'Supino Reto com Barra',
          'series': '4x10',
          'carga': '40 kg',
        },
        {
          'ficha': 'A',
          'grupo': 'Peito',
          'exercicio': 'Supino Inclinado com Halteres',
          'series': '4x10',
          'carga': '16 kg',
        },
        {
          'ficha': 'A',
          'grupo': 'Tríceps',
          'exercicio': 'Tríceps Testa',
          'series': '4x10',
          'carga': '10 kg',
        },
        {
          'ficha': 'B',
          'grupo': 'Pernas',
          'exercicio': 'Agachamento Livre',
          'series': '4x10',
          'carga': '30 kg',
        },
        {
          'ficha': 'B',
          'grupo': 'Pernas',
          'exercicio': 'Mesa Flexora',
          'series': '4x10',
          'carga': '25 kg',
        },
        {
          'ficha': 'C',
          'grupo': 'Costas',
          'exercicio': 'Remada Baixa Sentado',
          'series': '4x10',
          'carga': '40 kg',
        },
        {
          'ficha': 'C',
          'grupo': 'Bíceps',
          'exercicio': 'Rosca Scott',
          'series': '4x10',
          'carga': '12 kg',
        },
        {
          'ficha': 'D',
          'grupo': 'Ombros',
          'exercicio': 'Desenvolvimento com Halteres',
          'series': '4x10',
          'carga': '12 kg',
        },
      ];
    } else if (nivel == 'Avançado') {
      planoModelo = [
        {
          'ficha': 'A',
          'grupo': 'Peito',
          'exercicio': 'Supino Reto no Smith',
          'series': '4x8',
          'carga': '60 kg',
        },
        {
          'ficha': 'A',
          'grupo': 'Peito',
          'exercicio': 'Crucifixo Inclinado em Banco',
          'series': '4x10',
          'carga': '20 kg',
        },
        {
          'ficha': 'A',
          'grupo': 'Tríceps',
          'exercicio': 'Tríceps Pulley com Corda',
          'series': '4x12',
          'carga': '25 kg',
        },
        {
          'ficha': 'B',
          'grupo': 'Pernas',
          'exercicio': 'Agachamento Livre Pesado',
          'series': '4x8',
          'carga': '70 kg',
        },
        {
          'ficha': 'B',
          'grupo': 'Pernas',
          'exercicio': 'Cadeira Flexora',
          'series': '4x12',
          'carga': '40 kg',
        },
        {
          'ficha': 'C',
          'grupo': 'Costas',
          'exercicio': 'Remada Curvada com Barra',
          'series': '4x8',
          'carga': '50 kg',
        },
        {
          'ficha': 'C',
          'grupo': 'Bíceps',
          'exercicio': 'Rosca Direta na Barra W',
          'series': '4x10',
          'carga': '20 kg',
        },
        {
          'ficha': 'D',
          'grupo': 'Ombros',
          'exercicio': 'Elevação Lateral na Polia',
          'series': '4x12',
          'carga': '10 kg',
        },
      ];
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: Colors.amber)),
      );

      for (var ex in planoModelo) {
        await _workoutService.salvarTreino(
          alunoId: _alunoSelecionadoId!,
          ficha: ex['ficha']!,
          grupoMuscular: ex['grupo']!,
          nomeExercicios: ex['exercicio']!,
          seriesRepeticoes: ex['series']!,
          carga: ex['carga']!,
          videoUrl: '---',
        );
      }

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Plano Padrão ($nivel) injetado com sucesso na ficha do aluno! 🏋️‍♂️🔥',
          ),
          backgroundColor: Colors.green[800],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      print("Erro ao aplicar plano padrão: $e");
    }
  }

  // =========================================================================
  // TREINO PADRÃO DINÂMICO (Firestore)
  // =========================================================================

  void _abrirPopupAplicarTreinoPadrao() {
    if (_alunoSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um aluno antes de aplicar o treino padrão.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String nivel  = 'Iniciante';
    String perfil = 'Feminino';

    const niveis  = ['Iniciante', 'Intermediário', 'Avançado'];
    const perfis  = ['Feminino', 'Masculino'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.fitness_center, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('Aplicar Treino Padrão', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escolha o nível e perfil para aplicar na ficha do aluno:',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: nivel,
                decoration: const InputDecoration(
                  labelText: 'Nível',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: niveis.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                onChanged: (v) => setPopupState(() => nivel = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: perfil,
                decoration: const InputDecoration(
                  labelText: 'Perfil',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: perfis.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setPopupState(() => perfil = v!),
              ),
              const SizedBox(height: 8),
              Text(
                'Modelo: ${WorkoutService.gerarModeloId(nivel, perfil)}',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ],
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
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Aplicar'),
              onPressed: () {
                Navigator.pop(context);
                _aplicarTreinoPadraoFirestore(nivel, perfil);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aplicarTreinoPadraoFirestore(String nivel, String perfil) async {
    if (_alunoSelecionadoId == null) return;

    final modeloId = WorkoutService.gerarModeloId(nivel, perfil);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );

    try {
      QuerySnapshot snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('treinos_padrao')
            .doc(modeloId)
            .collection('exercicios')
            .orderBy('criadoEm')
            .get();
      } on FirebaseException catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        final msg = e.code == 'permission-denied'
            ? 'Sem permissão para acessar os treinos padrão. Verifique as regras do Firestore.'
            : 'Erro ao acessar treinos padrão: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 6)),
        );
        return;
      }

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Modelo "$nivel / $perfil" ainda não foi configurado.\n'
              'Acesse "Editar Modelos" para cadastrar os exercícios.',
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      for (final doc in snap.docs) {
        final dados = doc.data() as Map<String, dynamic>;
        await _workoutService.salvarTreino(
          alunoId:          _alunoSelecionadoId!,
          ficha:            dados['ficha']?.toString()    ?? 'A',
          grupoMuscular:    dados['grupo']?.toString()    ?? 'Peito',
          nomeExercicios:   dados['exercicio']?.toString() ?? '',
          seriesRepeticoes: dados['series']?.toString()   ?? '3x12',
          carga:            dados['carga']?.toString()    ?? '---',
          videoUrl:         dados['videoUrl']?.toString() ?? '---',
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Treino Padrão ($nivel / $perfil) aplicado com sucesso! 🏋️‍♂️',
          ),
          backgroundColor: Colors.green[800],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao aplicar treino padrão: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _abrirGerenciadorTreinosPadrao() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TreinosPadraoPage(eAdmin: _eAdminGeral),
      ),
    );
  }

  void _abrirScannerDeRefeicao() {
    final picker = ImagePicker();
    bool analisando = false;
    Map<String, dynamic>? resultadoAnalise;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.restaurant, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Scanner de Refeição IA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!analisando && resultadoAnalise == null) ...[
                const Text(
                  'Tire uma foto do seu prato para a IA calcular calorias e proteínas automaticamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                  ),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text(
                    'Bater Foto do Prato',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final XFile? foto = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 70,
                    );
                    if (foto != null) {
                      setPopupState(() => analisando = true);

                      final bytes = await foto.readAsBytes();
                      final resultado = await _aiService
                          .analisarRefeicaoPorFoto(bytes);

                      setPopupState(() {
                        analisando = false;
                        resultadoAnalise = resultado;
                      });
                    }
                  },
                ),
              ],
              if (analisando) ...[
                const SizedBox(height: 12),
                const CircularProgressIndicator(color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'O Gemini está analisando os macros do prato...',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
              if (resultadoAnalise != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🍽️ ${resultadoAnalise!['descricao']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(height: 1),
                      ),
                      Text(
                        '🔥 Calorias: ${resultadoAnalise!['calorias']} kcal',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '💪 Proteínas: ${resultadoAnalise!['proteinas']}g',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.amber,
                    minimumSize: const Size.fromHeight(42),
                  ),
                  onPressed: () async {
                    DateTime agora = DateTime.now();
                    String dataApenasDiaStr =
                        "${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}";

                    await FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(_alunoSelecionadoId)
                        .collection('diario_alimentar')
                        .add({
                          'descricao': resultadoAnalise!['descricao'],
                          'calorias':
                              double.tryParse(
                                resultadoAnalise!['calorias'].toString(),
                              ) ??
                              0.0,
                          'proteinas':
                              double.tryParse(
                                resultadoAnalise!['proteinas'].toString(),
                              ) ??
                              0.0,
                          'dataApenasDia': dataApenasDiaStr,
                          'dataRegistro': FieldValue.serverTimestamp(),
                        });

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Refeição salva no seu diário de nutrição! 🍗📊',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text(
                    'Confirmar e Salvar no Diário',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
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
          ],
        ),
      ),
    );
  }

  void _mostrarPopupCompraPlusIA() async {
    if (_alunoSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aluno não identificado. Faça login novamente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.purple)),
    );

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('criarPixScannerPro');

      final result = await callable.call();

      if (!mounted) return;
      Navigator.pop(context);

      final Map<String, dynamic> dados = Map<String, dynamic>.from(
        result.data as Map,
      );

      final String pagamentoId = dados['pagamentoId'].toString();
      final String qrCode = dados['qrCode'].toString();
      final DateTime expiraEm = DateTime.parse(dados['expiraEm'].toString());

      _abrirPopupPixDinamicoMercadoPago(
        pagamentoId: pagamentoId,
        qrCode: qrCode,
        expiraEm: expiraEm,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar PIX: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _abrirPopupPixDinamicoMercadoPago({
    required String pagamentoId,
    required String qrCode,
    required DateTime expiraEm,
  }) {
    Timer? timer;
    bool pagamentoAprovado = false;
    bool consultando = false;
    int segundosRestantes = expiraEm.difference(DateTime.now()).inSeconds;

    if (segundosRestantes < 0) {
      segundosRestantes = 0;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) async {
              final restante = expiraEm.difference(DateTime.now()).inSeconds;

              if (!mounted) {
                t.cancel();
                return;
              }

              setModalState(() {
                segundosRestantes = restante > 0 ? restante : 0;
              });

              if (segundosRestantes <= 0 && !pagamentoAprovado) {
                t.cancel();

                setModalState(() {
                  consultando = false;
                });

                return;
              }

              if (segundosRestantes % 5 == 0 &&
                  !consultando &&
                  !pagamentoAprovado) {
                consultando = true;

                final aprovado = await _consultarStatusPixScannerPro(
                  pagamentoId,
                );

                consultando = false;

                if (aprovado && mounted) {
                  pagamentoAprovado = true;
                  t.cancel();

                  if (_alunoSelecionadoId != null) {
                    await FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(_alunoSelecionadoId)
                        .set({
                          'iaStatusAssinatura': 'Ativo',
                          'dataInicioIA': FieldValue.serverTimestamp(),
                          'dataFimIA': Timestamp.fromDate(
                            DateTime.now().add(const Duration(days: 30)),
                          ),
                        }, SetOptions(merge: true));
                  }

                  if (mounted) {
                    setState(() {});
                  }

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Pagamento aprovado! Scanner PRO liberado por 30 dias.',
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 6),
                    ),
                  );
                }
              }
            });

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SizedBox(
                width: 390,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.purple[700],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.workspace_premium,
                                color: Colors.white,
                                size: 34,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Scanner Nutricional PRO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        const Text(
                          'Pague o PIX para liberar automaticamente',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'R\$ 20,00 / mês',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.purple,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: segundosRestantes > 60
                                ? Colors.green.withOpacity(0.12)
                                : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: segundosRestantes > 60
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          child: Text(
                            segundosRestantes > 0
                                ? 'Tempo restante: ${_formatarTempoPix(segundosRestantes)}'
                                : 'Tempo expirado',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: segundosRestantes > 60
                                  ? Colors.green[800]
                                  : Colors.orange[900],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          width: 230,
                          height: 230,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: QrImageView(
                            data: qrCode,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 14),

                        const Text(
                          'PIX Copia e Cola',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(
                            minHeight: 70,
                            maxHeight: 125,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              qrCode,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purple,
                              side: const BorderSide(color: Colors.purple),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: qrCode),
                              );

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Código PIX copiado!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text(
                              'Copiar código PIX',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            consultando
                                ? 'Verificando pagamento...'
                                : 'Após pagar, aguarde. A liberação será automática quando o Mercado Pago confirmar.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: Colors.black87,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: TextButton(
                                  onPressed: () {
                                    timer?.cancel();
                                    Navigator.pop(dialogContext);
                                  },
                                  child: const Text(
                                    'Fechar',
                                    style: TextStyle(color: Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text(
                                    'Verificar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final aprovado =
                                        await _consultarStatusPixScannerPro(
                                          pagamentoId,
                                        );

                                    if (aprovado && mounted) {
                                      pagamentoAprovado = true;
                                      timer?.cancel();

                                      if (_alunoSelecionadoId != null) {
                                        await FirebaseFirestore.instance
                                            .collection('usuarios')
                                            .doc(_alunoSelecionadoId)
                                            .set({
                                              'iaStatusAssinatura': 'Ativo',
                                              'dataInicioIA':
                                                  FieldValue.serverTimestamp(),
                                              'dataFimIA': Timestamp.fromDate(
                                                DateTime.now().add(
                                                  const Duration(days: 30),
                                                ),
                                              ),
                                            }, SetOptions(merge: true));
                                      }

                                      if (mounted) {
                                        setState(() {});
                                      }

                                      Navigator.pop(dialogContext);

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Pagamento aprovado! Scanner PRO liberado.',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      if (!mounted) return;

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Pagamento ainda não confirmado.',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      timer?.cancel();
    });
  }

  Future<bool> _consultarStatusPixScannerPro(String pagamentoId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('consultarStatusPixScannerPro');

      final result = await callable.call({'pagamentoId': pagamentoId});

      final Map<String, dynamic> dados = Map<String, dynamic>.from(
        result.data as Map,
      );

      return dados['aprovado'] == true;
    } catch (e) {
      print('Erro ao consultar status do PIX: $e');
      return false;
    }
  }

  void _mostrarPopupCompraAvaliacaoFisicaIA({required bool combo}) async {
    if (_alunoSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aluno não identificado. Selecione um aluno ou faça login novamente.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      ),
    );

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('criarPixAvaliacaoFisicaPro');

      final result = await callable.call({
        'tipoPlano': combo ? 'combo_performance_ia' : 'avaliacao_fisica_pro',
      });

      if (!mounted) return;
      Navigator.pop(context);

      final Map<String, dynamic> dados = Map<String, dynamic>.from(
        result.data as Map,
      );
      final String pagamentoId = dados['pagamentoId'].toString();
      final String qrCode = dados['qrCode'].toString();
      final DateTime expiraEm = DateTime.parse(dados['expiraEm'].toString());
      final String plano =
          dados['plano']?.toString() ??
          (combo ? 'Combo Performance IA' : 'Evolução Física PRO');
      final double valor =
          double.tryParse(dados['valor'].toString()) ?? (combo ? 29.90 : 19.90);

      _abrirPopupPixDinamicoAvaliacaoFisica(
        pagamentoId: pagamentoId,
        qrCode: qrCode,
        expiraEm: expiraEm,
        combo: combo,
        plano: plano,
        valor: valor,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar PIX da Evolução Física PRO: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _abrirPopupPixDinamicoAvaliacaoFisica({
    required String pagamentoId,
    required String qrCode,
    required DateTime expiraEm,
    required bool combo,
    required String plano,
    required double valor,
  }) {
    Timer? timer;
    bool pagamentoAprovado = false;
    bool consultando = false;
    int segundosRestantes = expiraEm.difference(DateTime.now()).inSeconds;

    if (segundosRestantes < 0) segundosRestantes = 0;

    Future<void> liberarLocalmente() async {
      if (_alunoSelecionadoId == null) return;
      final agora = DateTime.now();
      final Map<String, dynamic> dadosLiberacao = {
        'avaliacaoFisicaStatusAssinatura': 'Ativo',
        'planoAvaliacaoFisica': plano,
        'valorAvaliacaoFisica': valor,
        'dataInicioAvaliacaoFisica': FieldValue.serverTimestamp(),
        'dataFimAvaliacaoFisica': Timestamp.fromDate(
          agora.add(const Duration(days: 30)),
        ),
        'avaliacaoFisicaIAMesReferencia': _mesReferenciaAtualAvaliacaoFisica(),
        'avaliacaoFisicaIAUsosMes': 0,
        'pagamentoAvaliacaoFisicaAtualId': pagamentoId,
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      if (combo) {
        dadosLiberacao.addAll({
          'iaStatusAssinatura': 'Ativo',
          'dataInicioIA': FieldValue.serverTimestamp(),
          'dataFimIA': Timestamp.fromDate(agora.add(const Duration(days: 30))),
          'pagamentoScannerAtualId': pagamentoId,
        });
      }

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_alunoSelecionadoId)
          .set(dadosLiberacao, SetOptions(merge: true));
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) async {
              final restante = expiraEm.difference(DateTime.now()).inSeconds;

              if (!mounted) {
                t.cancel();
                return;
              }

              setModalState(() {
                segundosRestantes = restante > 0 ? restante : 0;
              });

              if (segundosRestantes <= 0 && !pagamentoAprovado) {
                t.cancel();
                setModalState(() => consultando = false);
                return;
              }

              if (segundosRestantes % 5 == 0 &&
                  !consultando &&
                  !pagamentoAprovado) {
                consultando = true;
                final aprovado = await _consultarStatusPixAvaliacaoFisicaPro(
                  pagamentoId,
                );
                consultando = false;

                if (aprovado && mounted) {
                  pagamentoAprovado = true;
                  t.cancel();
                  await liberarLocalmente();
                  if (mounted) setState(() {});
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$plano liberado por 30 dias!'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              }
            });

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SizedBox(
                width: 390,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.assignment_ind,
                                color: Colors.white,
                                size: 34,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                plano,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Pague o PIX para liberar automaticamente',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')} / mês',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: segundosRestantes > 60
                                ? Colors.green.withOpacity(0.12)
                                : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: segundosRestantes > 60
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          child: Text(
                            segundosRestantes > 0
                                ? 'Tempo restante: ${_formatarTempoPix(segundosRestantes)}'
                                : 'Tempo expirado',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: segundosRestantes > 60
                                  ? Colors.green[800]
                                  : Colors.orange[900],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 230,
                          height: 230,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: QrImageView(
                            data: qrCode,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'PIX Copia e Cola',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(
                            minHeight: 70,
                            maxHeight: 125,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              qrCode,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              side: const BorderSide(color: Colors.deepPurple),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: qrCode),
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Código PIX copiado!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text(
                              'Copiar código PIX',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            consultando
                                ? 'Verificando pagamento...'
                                : 'Após pagar, aguarde. A liberação será automática quando o Mercado Pago confirmar.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: TextButton(
                                  onPressed: () {
                                    timer?.cancel();
                                    Navigator.pop(dialogContext);
                                  },
                                  child: const Text(
                                    'Fechar',
                                    style: TextStyle(color: Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text(
                                    'Verificar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final aprovado =
                                        await _consultarStatusPixAvaliacaoFisicaPro(
                                          pagamentoId,
                                        );
                                    if (aprovado && mounted) {
                                      pagamentoAprovado = true;
                                      timer?.cancel();
                                      await liberarLocalmente();
                                      if (mounted) setState(() {});
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '$plano liberado por 30 dias!',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Pagamento ainda não confirmado.',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) => timer?.cancel());
  }

  Future<bool> _consultarStatusPixAvaliacaoFisicaPro(String pagamentoId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('consultarStatusPixAvaliacaoFisicaPro');

      final result = await callable.call({'pagamentoId': pagamentoId});
      final Map<String, dynamic> dados = Map<String, dynamic>.from(
        result.data as Map,
      );
      return dados['aprovado'] == true;
    } catch (e) {
      print('Erro ao consultar status do PIX da Avaliação Física PRO: $e');
      return false;
    }
  }

  String _formatarTempoPix(int segundos) {
    final minutos = segundos ~/ 60;
    final restoSegundos = segundos % 60;

    final minutosFormatado = minutos.toString().padLeft(2, '0');
    final segundosFormatado = restoSegundos.toString().padLeft(2, '0');

    return '$minutosFormatado:$segundosFormatado';
  }

  Widget _beneficioScannerPro({
    required IconData icon,
    required String titulo,
    required String texto,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.purple, size: 20),
          const SizedBox(height: 5),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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

  String _calcularStringVencimentoCompleta(int dia, String status) {
    DateTime hoje = DateTime.now();
    int mesAlvo = hoje.month;
    int anoAlvo = MackenzieAnoAjuste(hoje.year);

    if (status == 'Pago') {
      mesAlvo++;
      if (mesAlvo > 12) {
        mesAlvo = 1;
        anoAlvo++;
      }
    }

    String diaStr = dia.toString().padLeft(2, '0');
    String mesStr = mesAlvo.toString().padLeft(2, '0');
    String anoCurto = anoAlvo.toString().substring(2);

    if (status == 'Pago') {
      return "Próx. Pgto: $diaStr/$mesStr/$anoCurto";
    } else {
      return "Vencimento: $diaStr/$mesStr/$anoCurto";
    }
  }

  int MackenzieAnoAjuste(int yr) {
    return yr;
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
              'Plano Atual: ${dados['plano'] ?? 'Mensal'} • ${_calcularStringVencimentoCompleta(diaVencimento, status)}',
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
                        onChanged: (_) => setState(() {}),
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
                        onChanged: (_) => setState(() {}),
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
                        onChanged: (_) => setState(() {}),
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Senha Inicial (Mínimo 6 caracteres)',
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(42),
                        ),
                        onPressed: _cadastrarNovoProfessor,
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'Salvar / Cadastrar Professor',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Professores cadastrados',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('usuarios')
                            .where('cargo', isEqualTo: 'professor')
                            .snapshots(),
                        builder: (context, snapProfessores) {
                          if (!snapProfessores.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: LinearProgressIndicator(
                                color: Colors.amber,
                              ),
                            );
                          }

                          final professores = snapProfessores.data!.docs;

                          if (professores.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Text(
                                'Nenhum professor cadastrado ainda.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: professores.length,
                            itemBuilder: (context, index) {
                              final doc = professores[index];
                              final dados = doc.data() as Map<String, dynamic>;
                              final nome = (dados['nome'] ?? 'Professor')
                                  .toString();
                              final email = (dados['email'] ?? '---')
                                  .toString();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Colors.amber,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nome,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            email,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Editar professor',
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.amber,
                                      ),
                                      onPressed: () =>
                                          _abrirEdicaoProfessor(doc.id, dados),
                                    ),
                                    IconButton(
                                      tooltip: 'Excluir professor',
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          _confirmarExclusaoProfessor(
                                            doc.id,
                                            nome,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
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
                        labelText: 'Senha de Acesso (Mínimo 6 caracteres)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _novoCellularController,
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
            if (snapshot.hasError) {
              final erro = snapshot.error.toString();
              final msgErro = erro.contains('permission-denied') || erro.contains('PERMISSION_DENIED')
                  ? 'Sem permissão para listar alunos.\nVerifique as Regras do Firestore.'
                  : 'Erro ao carregar alunos: $erro';
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        msgErro,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData)
              return const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );

            var alunos = snapshot.data!.docs.where((doc) {
              var dados = doc.data() as Map<String, dynamic>;
              String nome = (dados['nome'] ?? '').toString().toLowerCase();
              String cargo = (dados['cargo'] ?? '').toString().toLowerCase().trim();
              final bool legacyAluno = dados['cargo'] == null && dados['eProfessor'] != true;
              final bool ehAluno = cargo == 'aluno' || legacyAluno;
              return nome.contains(_filtroBuscaAlunos) && ehAluno;
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
                String statusPag = dados['statusPagamento'] ?? 'Pendente';
                int diaVenc = dados['diaVencimento'] ?? 10;

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
                      'Tel: $celularAluno | ${_calcularStringVencimentoCompleta(diaVenc, statusPag)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.monetization_on,
                            color: Colors.green,
                            size: 22,
                          ),
                          tooltip: 'Dar baixa / Financeiro',
                          onPressed: () {
                            _abrirGerenciamentoFinanceiro(
                              doc.id,
                              dados['nome'] ?? 'Aluno',
                              dados,
                            );
                          },
                        ),
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      WidgetExpandido(
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
                  ),
                  const SizedBox(height: 10),

                  Card(
                    color: Colors.blueGrey[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.blueGrey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.fitness_center, color: Colors.deepPurple, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Treino Padrão',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.play_circle_outline, size: 16),
                                  label: const Text(
                                    'Aplicar Treino Padrão',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _abrirPopupAplicarTreinoPadrao,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black87,
                                    foregroundColor: Colors.amber,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.edit_note, size: 16),
                                  label: const Text(
                                    'Editar Modelos',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _abrirGerenciadorTreinosPadrao,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Selecione nível e perfil na tela de aplicação.\nUse "Editar Modelos" para criar ou customizar.',
                            style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
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

                      final chavesValidas = docsEx
                          .map((de) {
                            var exData = de.data() as Map<String, dynamic>;
                            return "${exData['nome'] ?? ''}|||${exData['videoUrl'] ?? '---'}";
                          })
                          .toSet()
                          .toList();

                      if (_exercicioSelecionadoCardapio != null &&
                          !chavesValidas.contains(
                            _exercicioSelecionadoCardapio,
                          )) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _exercicioSelecionadoCardapio = null;
                          });
                        });
                      }

                      return DropdownButtonFormField<String>(
                        value:
                            chavesValidas.contains(
                              _exercicioSelecionadoCardapio,
                            )
                            ? _exercicioSelecionadoCardapio
                            : null,
                        hint: const Text('2. Escolha o Exercício'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: chavesValidas.map((valorComposto) {
                          String nomeExibicao = valorComposto.split("|||")[0];
                          return DropdownMenuItem<String>(
                            value: valorComposto,
                            child: Text(nomeExibicao),
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
        if (snapshot.hasError) {
          final erro = snapshot.error.toString();
          final msg = erro.contains('permission-denied') || erro.contains('PERMISSION_DENIED')
              ? 'Sem permissão para acessar dados financeiros.\nVerifique as Regras do Firestore.'
              : 'Erro ao carregar financeiro: $erro';
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
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(msg, style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),
          );
        }

        double faturamentoTotalPago = 0.0;
        double faturamentoTotalPendente = 0.0;
        double faturamentoTotalAtrasado = 0.0;

        double receitaPlanosArrecadada = 0.0;
        double receitaScannerIAArrecadada = 0.0;
        double receitaAvaliacaoFisicaIAArrecadada = 0.0;

        List<QueryDocumentSnapshot> filaAprovacaoIA = [];
        List<Map<String, dynamic>> alunosAtivosScannerIA = [];
        List<Map<String, dynamic>> alunosAtivosAvaliacaoFisicaIA = [];
        List<Map<String, dynamic>> tabelaDeReceitasDetalhadas = [];

        if (snapshot.hasData && snapshot.data != null) {
          for (var doc in snapshot.data!.docs) {
            var d = doc.data() as Map<String, dynamic>?;
            if (d == null) continue;

            String cargo = (d['cargo'] ?? 'aluno')
                .toString()
                .toLowerCase()
                .trim();
            if (cargo == 'aluno') {
              String nomeAluno = d['nome'] ?? 'Aluno';
              String celularAluno = d['celular'] ?? '---';
              String iaStatus = d['iaStatusAssinatura'] ?? 'NaoAtivado';
              String statusPagamento = (d['statusPagamento'] ?? 'Pendente')
                  .toString()
                  .trim();
              int diaVencimento =
                  int.tryParse(d['diaVencimento'].toString()) ?? 10;
              int diaHoje = DateTime.now().day;

              if (statusPagamento == 'Pendente' && diaHoje > diaVencimento) {
                statusPagamento = 'Atrasado';
              }

              if (iaStatus == 'PendenteAprovacao') {
                filaAprovacaoIA.add(doc);
              }

              if (iaStatus == 'Ativo') {
                alunosAtivosScannerIA.add({
                  'nome': nomeAluno,
                  'celular': celularAluno,
                  'statusPagamento': statusPagamento,
                });
              }

              final bool avaliacaoFisicaAtiva = _avaliacaoFisicaProAtiva(d);
              final String planoAvaliacaoFisica =
                  (d['planoAvaliacaoFisica'] ?? 'Evolução Física PRO')
                      .toString();
              final double valorAvaliacaoFisica =
                  double.tryParse(
                    (d['valorAvaliacaoFisica'] ??
                            (planoAvaliacaoFisica == 'Combo Performance IA'
                                ? 29.90
                                : 19.90))
                        .toString(),
                  ) ??
                  (planoAvaliacaoFisica == 'Combo Performance IA'
                      ? 29.90
                      : 19.90);

              if (avaliacaoFisicaAtiva) {
                alunosAtivosAvaliacaoFisicaIA.add({
                  'nome': nomeAluno,
                  'celular': celularAluno,
                  'statusPagamento': statusPagamento,
                  'plano': planoAvaliacaoFisica,
                  'valor': valorAvaliacaoFisica,
                });
              }

              double valorPlano = 0.0;
              if (d['valorMensalidade'] != null) {
                valorPlano =
                    double.tryParse(d['valorMensalidade'].toString()) ?? 0.0;
              } else if (d['valor'] != null) {
                valorPlano = double.tryParse(d['valor'].toString()) ?? 0.0;
              }

              if (statusPagamento == 'Pago') {
                receitaPlanosArrecadada += valorPlano;
                faturamentoTotalPago += valorPlano;
              } else if (statusPagamento == 'Atrasado') {
                faturamentoTotalAtrasado += valorPlano;
              } else {
                faturamentoTotalPendente += valorPlano;
              }

              String informacaoDataVencimento =
                  _calcularStringVencimentoCompleta(
                    diaVencimento,
                    statusPagamento,
                  );

              if (valorPlano > 0) {
                tabelaDeReceitasDetalhadas.add({
                  'aluno': "$nomeAluno ($informacaoDataVencimento)",
                  'tipo': 'Plano (${d['plano'] ?? 'Mensal'})',
                  'valor': valorPlano,
                  'status': statusPagamento,
                  'cor': _obterCorStatus(statusPagamento),
                });
              }

              if (iaStatus == 'Ativo' &&
                  !(avaliacaoFisicaAtiva &&
                      planoAvaliacaoFisica == 'Combo Performance IA')) {
                receitaScannerIAArrecadada += 20.0;

                if (statusPagamento == 'Pago') {
                  faturamentoTotalPago += 20.0;
                } else if (statusPagamento == 'Atrasado') {
                  faturamentoTotalAtrasado += 20.0;
                } else {
                  faturamentoTotalPendente += 20.0;
                }

                tabelaDeReceitasDetalhadas.add({
                  'aluno': "$nomeAluno ($informacaoDataVencimento)",
                  'tipo': 'Scanner IA PRO 🧠',
                  'valor': 20.0,
                  'status': statusPagamento,
                  'cor': Colors.purple,
                });
              }

              if (avaliacaoFisicaAtiva) {
                receitaAvaliacaoFisicaIAArrecadada += valorAvaliacaoFisica;

                if (statusPagamento == 'Pago') {
                  faturamentoTotalPago += valorAvaliacaoFisica;
                } else if (statusPagamento == 'Atrasado') {
                  faturamentoTotalAtrasado += valorAvaliacaoFisica;
                } else {
                  faturamentoTotalPendente += valorAvaliacaoFisica;
                }

                tabelaDeReceitasDetalhadas.add({
                  'aluno': "$nomeAluno ($informacaoDataVencimento)",
                  'tipo': planoAvaliacaoFisica,
                  'valor': valorAvaliacaoFisica,
                  'status': statusPagamento,
                  'cor': Colors.deepPurple,
                });
              }
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.black,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Faturamento Consolidado da Academia',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _construirMiniCardFaturamento(
                          'Total Arrecadado',
                          'R\$ ${faturamentoTotalPago.toStringAsFixed(2)}',
                          Colors.green,
                        ),
                        const SizedBox(width: 6),
                        _construirMiniCardFaturamento(
                          'Total Esperado',
                          'R\$ ${faturamentoTotalPendente.toStringAsFixed(2)}',
                          Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        _construirMiniCardFaturamento(
                          'Total Atrasado',
                          'R\$ ${faturamentoTotalAtrasado.toStringAsFixed(2)}',
                          Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pie_chart, color: Colors.blueGrey, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Divisão de Receita Arrecadada',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🏋️‍♂️ Fichas & Planos de Academia:',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        Text(
                          'R\$ ${receitaPlanosArrecadada.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🧠 Adicionais Scanner Nutricional IA:',
                          style: TextStyle(fontSize: 13, color: Colors.purple),
                        ),
                        Text(
                          'R\$ ${receitaScannerIAArrecadada.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📊 Avaliação Física / Performance IA:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.deepPurple,
                          ),
                        ),
                        Text(
                          'R\$ ${receitaAvaliacaoFisicaIAArrecadada.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.purple.withOpacity(0.3)),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.psychology, color: Colors.purple),
                title: Text(
                  'Alunos Ativos no Scanner IA PRO 🧠 (${alunosAtivosScannerIA.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.purple,
                  ),
                ),
                children: [
                  if (alunosAtivosScannerIA.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhum aluno com assinatura ativa no momento.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: alunosAtivosScannerIA.length,
                      itemBuilder: (context, idx) {
                        var alunoIA = alunosAtivosScannerIA[idx];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.purple,
                            size: 18,
                          ),
                          title: Text(
                            alunoIA['nome'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('WhatsApp: ${alunoIA['celular']}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _obterCorStatus(
                                alunoIA['statusPagamento'],
                              ).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              alunoIA['statusPagamento'],
                              style: TextStyle(
                                color: _obterCorStatus(
                                  alunoIA['statusPagamento'],
                                ),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.deepPurple.withOpacity(0.3)),
              ),
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(
                  Icons.assignment_ind,
                  color: Colors.deepPurple,
                ),
                title: Text(
                  'Alunos Ativos na Evolução Física / Performance IA (${alunosAtivosAvaliacaoFisicaIA.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.deepPurple,
                  ),
                ),
                children: [
                  if (alunosAtivosAvaliacaoFisicaIA.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhum aluno com Evolução Física PRO ou Combo ativo no momento.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: alunosAtivosAvaliacaoFisicaIA.length,
                      itemBuilder: (context, idx) {
                        var alunoIA = alunosAtivosAvaliacaoFisicaIA[idx];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.deepPurple,
                            size: 18,
                          ),
                          title: Text(
                            alunoIA['nome'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${alunoIA['plano']} • WhatsApp: ${alunoIA['celular']}',
                          ),
                          trailing: Text(
                            'R\$ ${(alunoIA['valor'] as double).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (filaAprovacaoIA.isNotEmpty) ...[
              const Text(
                '⚠️ Comprovantes PIX Recebidos (Scanner IA - R\$ 20)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filaAprovacaoIA.length,
                itemBuilder: (context, idx) {
                  var docAlunoIA = filaAprovacaoIA[idx];
                  var dadosAlunoIA = docAlunoIA.data() as Map<String, dynamic>;

                  return Card(
                    color: Colors.purple[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.purple[200]!),
                    ),
                    child: ListTile(
                      title: Text(
                        dadosAlunoIA['nome'] ?? 'Aluno',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Avisou que fez o PIX de R\$ 20,00 para o Scanner IA Pro.',
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(docAlunoIA.id)
                              .update({'iaStatusAssinatura': 'Ativo'});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Acesso PRO liberado com sucesso para ${dadosAlunoIA['nome']}! 🍗📊',
                              ),
                              backgroundColor: Colors.purple,
                            ),
                          );
                        },
                        child: const Text(
                          'Confirmar & Liberar PRO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Planilha Detalhada de Receitas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.black87),
                  onPressed: _abrirConfiguracaoDeValoresDoCardapio,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (tabelaDeReceitasDetalhadas.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('Nenhum lançamento financeiro registrado.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tabelaDeReceitasDetalhadas.length,
                itemBuilder: (context, index) {
                  var itemReceita = tabelaDeReceitasDetalhadas[index];
                  bool ehIA = itemReceita['tipo'].toString().contains(
                    'Scanner',
                  );

                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: Icon(
                        ehIA ? Icons.psychology : Icons.fitness_center,
                        color: ehIA ? Colors.purple : Colors.amber[800],
                        size: 20,
                      ),
                      title: Text(
                        itemReceita['aluno'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        itemReceita['tipo'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${itemReceita['valor'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ehIA ? Colors.purple : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            itemReceita['status'],
                            style: TextStyle(
                              color: itemReceita['cor'],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  Widget _construirTelaAplicativoDesatualizado() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_alt,
                size: 80,
                color: Colors.amber,
              ),
              const SizedBox(height: 24),
              const Text(
                'Nova Versão Disponível!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Lançamos melhorias cruciais, correções no cronômetro de descanso e a integração do Scanner de Alimentos via PIX!\n\nPara continuar treinando e registrando seus treinos, baixe a nova versão agora.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(220, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.download, fontWeight: FontWeight.bold),
                label: const Text(
                  'Baixar Atualização 🚀',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () {
                  print('Baixando nova versão de: $_linkDownloadNovoApk');
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Versão do seu celular: $_versaoCodigoAtual',
                style: const TextStyle(fontSize: 11, color: Colors.white30),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirCardAvaliacaoFisicaAluno() {
    if (_alunoSelecionadoId == null) return const SizedBox();

    String formatarNumero(dynamic valor, String unidade, {int casas = 1}) {
      final numero = double.tryParse((valor ?? 0).toString()) ?? 0.0;
      if (numero <= 0) return '---';
      final valorTexto = numero.toStringAsFixed(casas);
      return unidade.trim().isEmpty ? valorTexto : '$valorTexto $unidade';
    }

    String formatarDiferenca(dynamic atual, dynamic inicial, String unidade) {
      final valorAtual = double.tryParse((atual ?? 0).toString()) ?? 0.0;
      final valorInicial = double.tryParse((inicial ?? 0).toString()) ?? 0.0;

      if (valorAtual <= 0 || valorInicial <= 0) return '---';

      final diferenca = valorAtual - valorInicial;
      final sinal = diferenca > 0 ? '+' : '';
      return '$sinal${diferenca.toStringAsFixed(1)} $unidade';
    }

    Widget cardIndicador({
      required IconData icon,
      required String titulo,
      required String valor,
      required String diferenca,
      required Color cor,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cor.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: cor, size: 20),
              const SizedBox(height: 6),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: cor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Evolução: $diferenca',
                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_alunoSelecionadoId)
          .snapshots(),
      builder: (context, snapAluno) {
        if (!snapAluno.hasData || !snapAluno.data!.exists)
          return const SizedBox();

        final dadosAluno = snapAluno.data!.data() as Map<String, dynamic>;
        final proAtivo = _avaliacaoFisicaProAtiva(dadosAluno);
        final plano =
            (dadosAluno['planoAvaliacaoFisica'] ?? 'Evolução Física PRO')
                .toString();
        final limiteIA = _limiteMensalAnalisesAvaliacaoFisica(dadosAluno);
        final usosIA = _usosAnaliseAvaliacaoFisicaNoMes(dadosAluno);

        if (!proAtivo) {
          return _cardBloqueioAvaliacaoFisicaPro(professor: false);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_alunoSelecionadoId)
              .collection('avaliacoes_fisicas')
              .orderBy('dataAvaliacao', descending: true)
              .snapshots(),
          builder: (context, snapAvaliacoes) {
            if (!snapAvaliacoes.hasData) {
              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: LinearProgressIndicator(color: Colors.deepPurple),
                ),
              );
            }

            final avaliacoes = snapAvaliacoes.data!.docs;

            if (avaliacoes.isEmpty) {
              return Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.deepPurple.withOpacity(0.12),
                        child: const Icon(
                          Icons.monitor_weight,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Minha Evolução Física PRO',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Plano ativo: $plano | IA: $usosIA/$limiteIA análises no mês.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Ainda não há avaliação física registrada pelo professor.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final ultima = avaliacoes.first.data() as Map<String, dynamic>;
            final primeira = avaliacoes.last.data() as Map<String, dynamic>;
            final dataUltima = _formatarDataAvaliacao(ultima['dataAvaliacao']);

            return Card(
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.deepPurple.withOpacity(0.12),
                          child: const Icon(
                            Icons.insights,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Minha Evolução Física PRO',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Última avaliação: $dataUltima',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$plano | IA: $usosIA/$limiteIA no mês',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        cardIndicador(
                          icon: Icons.monitor_weight,
                          titulo: 'Peso atual',
                          valor: formatarNumero(ultima['peso'], 'kg'),
                          diferenca: formatarDiferenca(
                            ultima['peso'],
                            primeira['peso'],
                            'kg',
                          ),
                          cor: Colors.deepPurple,
                        ),
                        const SizedBox(width: 8),
                        cardIndicador(
                          icon: Icons.straighten,
                          titulo: 'Cintura',
                          valor: formatarNumero(ultima['cintura'], 'cm'),
                          diferenca: formatarDiferenca(
                            ultima['cintura'],
                            primeira['cintura'],
                            'cm',
                          ),
                          cor: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        cardIndicador(
                          icon: Icons.percent,
                          titulo: 'Gordura',
                          valor: formatarNumero(ultima['gorduraCorporal'], '%'),
                          diferenca: formatarDiferenca(
                            ultima['gorduraCorporal'],
                            primeira['gorduraCorporal'],
                            '%',
                          ),
                          cor: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        cardIndicador(
                          icon: Icons.accessibility_new,
                          titulo: 'Massa magra',
                          valor: formatarNumero(ultima['massaMagra'], 'kg'),
                          diferenca: formatarDiferenca(
                            ultima['massaMagra'],
                            primeira['massaMagra'],
                            'kg',
                          ),
                          cor: Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _linhaResumoAvaliacao(
                            'IMC',
                            formatarNumero(ultima['imc'], '', casas: 1),
                          ),
                          _linhaResumoAvaliacao(
                            'Abdômen',
                            formatarNumero(ultima['abdomen'], 'cm'),
                          ),
                          _linhaResumoAvaliacao(
                            'Quadril',
                            formatarNumero(ultima['quadril'], 'cm'),
                          ),
                          _linhaResumoAvaliacao(
                            'Peitoral',
                            formatarNumero(ultima['peitoral'], 'cm'),
                          ),
                          if ((ultima['observacoes'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Observações: ${ultima['observacoes']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text(
                        'Ver histórico completo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      children: avaliacoes.map((doc) {
                        final dados = doc.data() as Map<String, dynamic>;
                        final data = _formatarDataAvaliacao(
                          dados['dataAvaliacao'],
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Peso: ${formatarNumero(dados['peso'], 'kg')}',
                                  ),
                                  Text(
                                    'IMC: ${formatarNumero(dados['imc'], '', casas: 1)}',
                                  ),
                                  Text(
                                    'Gordura: ${formatarNumero(dados['gorduraCorporal'], '%')}',
                                  ),
                                  Text(
                                    'Cintura: ${formatarNumero(dados['cintura'], 'cm')}',
                                  ),
                                  Text(
                                    'Abdômen: ${formatarNumero(dados['abdomen'], 'cm')}',
                                  ),
                                  Text(
                                    'Quadril: ${formatarNumero(dados['quadril'], 'cm')}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _construirPainelHistoricoNutricional() {
    DateTime agora = DateTime.now();
    String hojeStr =
        "${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_alunoSelecionadoId)
          .collection('diario_alimentar')
          .orderBy('dataRegistro', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const LinearProgressIndicator(color: Colors.green);

        var refeicoesDocs = snapshot.data!.docs;

        double totalCaloriasHoje = 0.0;
        double totalProteinasHoje = 0.0;

        Map<String, List<Map<String, dynamic>>> refeicoesAgrupadasPorDia = {};
        Map<String, double> somaCaloriasPorDia = {};
        Map<String, double> somaProteinasPorDia = {};

        for (var doc in refeicoesDocs) {
          var dados = doc.data() as Map<String, dynamic>;
          String dia = dados['dataApenasDia'] ?? hojeStr;
          double kcal = double.tryParse(dados['calorias'].toString()) ?? 0.0;
          double prot = double.tryParse(dados['proteinas'].toString()) ?? 0.0;
          String desc = dados['descricao'] ?? 'Refeição';

          if (dia == hojeStr) {
            totalCaloriasHoje += kcal;
            totalProteinasHoje += prot;
          }

          if (!refeicoesAgrupadasPorDia.containsKey(dia)) {
            refeicoesAgrupadasPorDia[dia] = [];
            somaCaloriasPorDia[dia] = 0.0;
            somaProteinasPorDia[dia] = 0.0;
          }

          refeicoesAgrupadasPorDia[dia]!.add({
            'descricao': desc,
            'calorias': kcal,
            'proteinas': prot,
          });
          somaCaloriasPorDia[dia] = somaCaloriasPorDia[dia]! + kcal;
          somaProteinasPorDia[dia] = somaProteinasPorDia[dia]! + prot;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.green[800],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔥 Total Consumido Hoje',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Calorias',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${totalCaloriasHoje.toStringAsFixed(0)} kcal',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Proteínas',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${totalProteinasHoje.toStringAsFixed(1)}g',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              '🗓️ Histórico de Alimentação Diária',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            if (refeicoesAgrupadasPorDia.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Nenhuma refeição registrada no diário alimentar.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: refeicoesAgrupadasPorDia.keys.length,
                itemBuilder: (context, index) {
                  String dataChave = refeicoesAgrupadasPorDia.keys.elementAt(
                    index,
                  );
                  List<Map<String, dynamic>> itensDoDia =
                      refeicoesAgrupadasPorDia[dataChave]!;

                  double totalKcalDia = somaCaloriasPorDia[dataChave] ?? 0;
                  double totalProtDia = somaProteinasPorDia[dataChave] ?? 0;

                  String dataFormatadaExibicao = dataChave;
                  try {
                    List<String> partes = dataChave.split('-');
                    dataFormatadaExibicao =
                        "${partes[2]}/${partes[1]}/${partes[0]}";
                    if (dataChave == hojeStr) {
                      dataFormatadaExibicao = "Hoje ($dataFormatadaExibicao)";
                    }
                  } catch (_) {}

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ExpansionTile(
                      leading: Icon(
                        Icons.calendar_today,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      title: Text(
                        dataFormatadaExibicao,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Total: ${totalKcalDia.toStringAsFixed(0)} kcal | ${totalProtDia.toStringAsFixed(1)}g Proteína',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      children: itensDoDia.map((refeicaoItem) {
                        return ListTile(
                          dense: true,
                          title: Text(
                            refeicaoItem['descricao'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Text(
                            '+${refeicaoItem['calorias'].toStringAsFixed(0)} kcal  |  +${refeicaoItem['proteinas'].toStringAsFixed(1)}g',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                        );
                      }).toList(),
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

    if (_aplicativoDesatualizado) {
      return _construirTelaAplicativoDesatualizado();
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
                          _construirCardAvaliacaoFisicaProfessor(),
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

                  _construirCardAvaliacaoFisicaAluno(),
                  const SizedBox(height: 12),

                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(_alunoSelecionadoId)
                        .snapshots(),
                    builder: (context, snapUser) {
                      if (!snapUser.hasData || !snapUser.data!.exists)
                        return const SizedBox();

                      var dadosAluno =
                          snapUser.data!.data() as Map<String, dynamic>;
                      String iaStatus =
                          dadosAluno['iaStatusAssinatura'] ?? 'NaoAtivado';
                      Timestamp? dataInicioTimestamp =
                          dadosAluno['dataInicioDegustacao'] as Timestamp?;

                      int diasRestantes = 0;
                      bool emDegustacaoValida = false;

                      if (iaStatus == 'Degustacao' &&
                          dataInicioTimestamp != null) {
                        DateTime dataInicio = dataInicioTimestamp.toDate();
                        DateTime dataFimDegustacao = dataInicio.add(
                          const Duration(days: 7),
                        );
                        DateTime hoje = DateTime.now();

                        diasRestantes =
                            dataFimDegustacao.difference(hoje).inDays + 1;

                        if (hoje.isBefore(dataFimDegustacao) &&
                            diasRestantes >= 0) {
                          emDegustacaoValida = true;
                        } else {
                          emDegustacaoValida = false;
                          FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(_alunoSelecionadoId)
                              .update({'iaStatusAssinatura': 'Bloqueado'});
                          iaStatus = 'Bloqueado';
                        }
                      }

                      bool temAcessoLiberado =
                          (iaStatus == 'Ativo') || emDegustacaoValida;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: temAcessoLiberado
                                            ? Colors.green[100]
                                            : Colors.purple[100],
                                        radius: 22,
                                        child: Icon(
                                          Icons.restaurant,
                                          color: temAcessoLiberado
                                              ? Colors.green[800]
                                              : Colors.purple[800],
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Text(
                                                  'Scanner de Refeição (IA)',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                if (emDegustacaoValida)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '$diasRestantes d grátis',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Colors.amber[900],
                                                      ),
                                                    ),
                                                  ),
                                                if (iaStatus == 'Ativo')
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'PRO',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  ),
                                                if (iaStatus == 'Bloqueado')
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Expirado',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              iaStatus == 'PendenteAprovacao'
                                                  ? 'Aguardando liberação do professor...'
                                                  : (temAcessoLiberado
                                                        ? 'Bata foto do prato para calcular as macros!'
                                                        : 'Monitore proteínas e calorias por R\$ 20,00/mês.'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            if (!temAcessoLiberado &&
                                                iaStatus !=
                                                    'PendenteAprovacao' &&
                                                iaStatus != 'Bloqueado') ...[
                                              const SizedBox(height: 8),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.purple,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  minimumSize: const Size(
                                                    0,
                                                    34,
                                                  ),
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.workspace_premium,
                                                  size: 15,
                                                ),
                                                label: const Text(
                                                  'Assine agora o PRO',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onPressed:
                                                    _mostrarPopupCompraPlusIA,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      if (!temAcessoLiberado &&
                                          iaStatus == 'NaoAtivado')
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.purple[700],
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance
                                                .collection('usuarios')
                                                .doc(_alunoSelecionadoId)
                                                .update({
                                                  'iaStatusAssinatura':
                                                      'Degustacao',
                                                  'dataInicioDegustacao':
                                                      FieldValue.serverTimestamp(),
                                                });
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  '🎉 Período de 7 dias de testes grátis iniciado!',
                                                ),
                                                backgroundColor: Colors.purple,
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Testar Grátis',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (temAcessoLiberado)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green[700],
                                            foregroundColor: Colors.white,
                                          ),
                                          icon: const Icon(
                                            Icons.camera_alt,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            'Escanear',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: _abrirScannerDeRefeicao,
                                        ),
                                      if (!temAcessoLiberado &&
                                          iaStatus == 'Bloqueado')
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.purple,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: _mostrarPopupCompraPlusIA,
                                          child: const Text(
                                            'Contratar PRO',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (iaStatus == 'PendenteAprovacao')
                                        const Icon(
                                          Icons.hourglass_top,
                                          color: Colors.orange,
                                        ),
                                    ],
                                  ),

                                  if (iaStatus == 'Bloqueado') ...[
                                    const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Divider(),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.purple.withOpacity(
                                            0.25,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Assine o PRO para gerar um PIX seguro pelo Mercado Pago. Após o pagamento, o Scanner será liberado automaticamente.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          if (temAcessoLiberado) ...[
                            const SizedBox(height: 12),
                            _construirPainelHistoricoNutricional(),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),

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

  // =========================================================================
  // COMPATIBILIDADE CAMINHO ANTIGO × NOVO
  // =========================================================================

  Future<void> _migrarTreinosAntigos(String docIdAntigo) async {
    if (_alunoSelecionadoId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );

    try {
      final migrados = await _workoutService.migrarTreinosAntigos(
        alunoId: _alunoSelecionadoId!,
        docIdAntigo: docIdAntigo,
      );
      setState(() {
        _futureTreinosAntigos = null;
        _alunoIdCacheTreinosAntigos = null;
      });
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(
          migrados > 0
              ? 'Migração concluída! $migrados exercício${migrados != 1 ? 's' : ''} migrado${migrados != 1 ? 's' : ''}.'
              : 'Migração concluída. Todos os exercícios já existiam na estrutura atual.',
        ),
        backgroundColor: migrados > 0 ? Colors.green[800] : Colors.orange[700],
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Erro na migração: $e'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Widget _buildBannerFonteTreinos(String mensagem, Color cor, IconData icone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icone, color: cor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErroBannerTreinos(String erro) {
    final msg = erro.contains('permission-denied') || erro.contains('PERMISSION_DENIED')
        ? 'Sem permissão para acessar os treinos deste aluno.\nVerifique as Regras do Firestore.'
        : 'Erro ao carregar treinos: $erro';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
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
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildFichaTabBar(List<String> fichas) {
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
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18, color: Colors.blueAccent),
                    label: const Text(
                      'Nova Ficha',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      final prox = fichas.last.codeUnitAt(0) + 1;
                      final proximaLetra = String.fromCharCode(prox);
                      setState(() => _fichaSelecionadaAluno = proximaLetra);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Ficha $proximaLetra liberada! Agora basta vincular exercícios a ela. 🏋️‍♂️'),
                        backgroundColor: Colors.blue,
                      ));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    onPressed: _limparFichaCompleta,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: fichas.map((letraFicha) {
              final estaSelecionada = _fichaSelecionadaAluno == letraFicha;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: estaSelecionada ? Colors.black : Colors.white,
                    foregroundColor: estaSelecionada ? Colors.amber : Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => setState(() => _fichaSelecionadaAluno = letraFicha),
                  child: Text('TREINO $letraFicha'),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildExercicioCard(Map<String, dynamic> dadosTratados, {String? treinoId}) {
    final nomeDoExercicioItem = (dadosTratados['exercicios'] ?? 'Exercício').toString();
    final somenteLeitura = treinoId == null;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                icon: const Icon(Icons.play_circle_fill, color: Colors.amber, size: 36),
                onPressed: () => _assistirVideo(dadosTratados['videoUrl']),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!_eProfessor) _mostrarDetalhesExercicioAluno(dadosTratados);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomeDoExercicioItem,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dadosTratados['grupo'] ?? ''} | Reps: ${dadosTratados['series'] ?? ''} | Base: ${dadosTratados['carga'] ?? ''}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      if (somenteLeitura)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Somente leitura — use "Migrar treinos antigos" para editar',
                            style: TextStyle(fontSize: 10, color: Colors.orange),
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
                  icon: const Icon(Icons.history, color: Colors.blueGrey, size: 22),
                  tooltip: 'Ver Evolução de Força',
                  onPressed: () => _abrirHistoricoDeCargasDoExercicio(nomeDoExercicioItem),
                ),
                if (_eProfessor && !somenteLeitura) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange, size: 22),
                    onPressed: () => _abrirConfiguracaoExercicio(
                      dadosTratados['grupo'] ?? '',
                      nomeDoExercicioItem,
                      treinoId: treinoId,
                      seriesAtual: dadosTratados['series'],
                      cargaAtual: dadosTratados['carga'],
                      videoUrlAtual: dadosTratados['videoUrl'],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                    onPressed: () => _workoutService.excluirTreino(_alunoSelecionadoId!, treinoId),
                  ),
                ] else if (!_eProfessor) ...[
                  IconButton(
                    icon: const Icon(Icons.scale, color: Colors.green, size: 22),
                    tooltip: 'Anotar Peso de Hoje',
                    onPressed: () => _abrirPopupAnotarCarga(nomeDoExercicioItem),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline, color: Colors.amber, size: 24),
                    tooltip: 'Iniciar Descanso',
                    onPressed: () => _iniciarCronometroDescanso(nomeDoExercicioItem),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFichasComStreamNovo(List<QueryDocumentSnapshot> todosOsTreinos) {
    final letras = <String>{'A', 'B', 'C', _fichaSelecionadaAluno};
    for (final doc in todosOsTreinos) {
      final dados = doc.data() as Map<String, dynamic>;
      if (dados.containsKey('ficha')) {
        final letra = dados['ficha'].toString().toUpperCase().trim();
        if (letra.isNotEmpty) letras.add(letra);
      }
    }
    final listaFichas = letras.toList()..sort();
    if (!listaFichas.contains(_fichaSelecionadaAluno)) {
      _fichaSelecionadaAluno = listaFichas.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBannerFonteTreinos(
          'Treinos carregados da estrutura atual.',
          Colors.green,
          Icons.check_circle_outline,
        ),
        _buildFichaTabBar(listaFichas),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _workoutService.listarTreinosPorFicha(_alunoSelecionadoId!, _fichaSelecionadaAluno),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _buildErroBannerTreinos(snapshot.error.toString());
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.amber));
            }
            final treinos = snapshot.data!.docs;
            if (treinos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('Nenhum exercício cadastrado nesta série.')),
              );
            }
            return Column(
              children: treinos.map((t) {
                final dados = t.data() as Map<String, dynamic>;
                return _buildExercicioCard(dados, treinoId: t.id);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFichasComDadosAntigos(
    List<Map<String, dynamic>> treinosAntigos,
    String docIdAntigo,
  ) {
    final letras = <String>{'A', _fichaSelecionadaAluno};
    for (final t in treinosAntigos) {
      final letra = (t['ficha'] ?? 'A').toString().toUpperCase().trim();
      if (letra.isNotEmpty) letras.add(letra);
    }
    final listaFichas = letras.toList()..sort();
    if (!listaFichas.contains(_fichaSelecionadaAluno)) {
      _fichaSelecionadaAluno = listaFichas.first;
    }

    final fichaAtual = _fichaSelecionadaAluno;
    final exerciciosDaFicha = treinosAntigos
        .where((t) => (t['ficha'] ?? 'A').toString().toUpperCase().trim() == fichaAtual)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBannerFonteTreinos(
          'Treinos encontrados na estrutura antiga.',
          Colors.orange,
          Icons.history,
        ),
        if (_eProfessor) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.maxFinite,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.upload, size: 18),
              label: const Text('Migrar treinos antigos deste aluno', style: TextStyle(fontSize: 13)),
              onPressed: () => _migrarTreinosAntigos(docIdAntigo),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Os treinos serão copiados para a estrutura atual. Os dados originais não serão apagados.',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey),
          ),
        ],
        const SizedBox(height: 10),
        _buildFichaTabBar(listaFichas),
        const SizedBox(height: 12),
        if (exerciciosDaFicha.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Nenhum exercício nesta ficha (dados antigos).')),
          )
        else
          Column(children: exerciciosDaFicha.map((t) => _buildExercicioCard(t)).toList()),
      ],
    );
  }

  Widget _buildFichasVazias() {
    const listaFichas = ['A', 'B', 'C'];
    if (!listaFichas.contains(_fichaSelecionadaAluno)) _fichaSelecionadaAluno = 'A';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBannerFonteTreinos(
          'Nenhum treino encontrado para este aluno.',
          Colors.blueGrey,
          Icons.info_outline,
        ),
        _buildFichaTabBar(listaFichas),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: Text('Nenhum exercício cadastrado nesta série.')),
        ),
      ],
    );
  }

  Widget _construirListaDeTreinosEfetivos() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_alunoSelecionadoId)
          .collection('treinos')
          .snapshots(),
      builder: (context, snapshotGeralTreinos) {
        if (snapshotGeralTreinos.hasError) {
          return _buildErroBannerTreinos(snapshotGeralTreinos.error.toString());
        }
        if (!snapshotGeralTreinos.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final treinosNovos = snapshotGeralTreinos.data!.docs;

        if (treinosNovos.isNotEmpty) {
          return _buildFichasComStreamNovo(treinosNovos);
        }

        // Caminho novo vazio — verificar caminho antigo com cache para não re-executar ao trocar ficha
        if (_alunoIdCacheTreinosAntigos != _alunoSelecionadoId) {
          _futureTreinosAntigos = _workoutService.buscarTreinosAntigos(
            alunoId: _alunoSelecionadoId!,
            alunoNome: _alunoSelecionadoNome,
            email: _alunoSelecionadoEmail,
          );
          _alunoIdCacheTreinosAntigos = _alunoSelecionadoId;
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: _futureTreinosAntigos,
          builder: (context, snapAntigo) {
            if (snapAntigo.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.amber));
            }
            if (snapAntigo.hasError) {
              return _buildErroBannerTreinos(snapAntigo.error.toString());
            }

            final resultado = snapAntigo.data;
            if (resultado == null || (resultado['treinos'] as List).isEmpty) {
              return _buildFichasVazias();
            }

            return _buildFichasComDadosAntigos(
              List<Map<String, dynamic>>.from(resultado['treinos'] as List),
              resultado['docId'] as String,
            );
          },
        );
      },
    );
  }
}

class WidgetExpandido extends StatelessWidget {
  final Widget child;
  const WidgetExpandido({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: child);
  }
}
