import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/navigation_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _nomeController = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      if (!_isLogin) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _enviarFormulario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.logarComEmailESenha(
          _emailController.text,
          _senhaController.text,
        );
        await _navegarParaRotaCorreta();
      } else {
        await _cadastrarNovoUsuario();
      }
    } catch (e) {
      _mostrarMensagem(
        'Erro: ${e.toString().replaceAll(RegExp(r'\[.*\]'), '')}',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Após login bem-sucedido, consulta o perfil e navega para a rota correta.
  /// Admin/professor → /home direto.
  /// Aluno sem onboarding → /onboarding.
  /// Aluno com onboarding → /home.
  Future<void> _navegarParaRotaCorreta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _mostrarMensagem('Não foi possível identificar o usuário. Tente novamente.');
      return;
    }

    final rota = await NavigationService.definirRotaInicialUsuario(user);

    if (!mounted) return;
    _mostrarMensagem('Login realizado com sucesso!', correto: true);
    Navigator.of(context).pushReplacementNamed(rota);
  }

  Future<void> _cadastrarNovoUsuario() async {
    final user = await _authService.cadastrarComEmailESenha(
      _emailController.text,
      _senhaController.text,
    );

    if (user != null) {
      // Novos usuários cadastrados pela tela de login são sempre alunos.
      // Professores e admins são criados pelo painel administrativo.
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .set({
            'nome': _nomeController.text.trim().isEmpty
                ? 'Usuário Novo'
                : _nomeController.text.trim(),
            'email': _emailController.text.trim().toLowerCase(),
            'cargo': 'aluno',
            'statusPagamento': 'Pendente',
            'iaStatusAssinatura': 'NaoAtivado',
            'dataCadastro': FieldValue.serverTimestamp(),
          });

      await _navegarParaRotaCorreta();
    }
  }

  void _mostrarMensagem(String texto, {bool correto = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: correto ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textoBotao = _isLogin
        ? 'Entrar no Painel'
        : (_emailController.text.contains('admin')
            ? 'Registrar Professor'
            : 'Cadastrar Usuário');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1C1C1C), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.96),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 25,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha:0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.fitness_center,
                              size: 60,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'AndSport',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),

                    const Text(
                      'A sua saúde começa aqui',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber, width: 2),
                          ),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Insira seu nome completo'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail ou Usuário',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber, width: 2),
                        ),
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (v) =>
                          v == null || !v.contains('@')
                          ? 'Insira um e-mail válido'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha de Acesso',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber, width: 2),
                        ),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (v) => v == null || v.length < 6
                          ? 'A senha deve ter pelo menos 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _enviarFormulario,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.amber,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              textoBotao,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      style: TextButton.styleFrom(foregroundColor: Colors.black87),
                      child: Text(
                        _isLogin
                            ? 'Não tem uma conta? Cadastre-se'
                            : 'Já possui acesso? Faça Login',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
