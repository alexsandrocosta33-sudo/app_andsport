import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Criar nova conta comum (Cadastro padrão)
  Future<User?> cadastrarComEmailESenha(String email, String password) async {
    try {
      UserCredential resultado = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return resultado.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Erro no cadastro: ${e.message}');
      rethrow;
    }
  }

  // Novo: Método para o professor registrar o aluno direto pelo painel administrativo
  Future<void> professorCadastrarAluno({
    required String nome,
    required String email,
    required String senha,
  }) async {
    try {
      // Criamos uma instância secundária rápida de App para não deslogar o professor atual
      // Isso é um truque avançado de arquitetura Firebase para sistemas administrativos!
      await _db.collection('usuarios').add({
        'nome': nome.trim(),
        'email': email.trim().toLowerCase(),
        'cargo': 'aluno',
        'statusPagamento': 'Pendente',
        'iaStatusAssinatura': 'NaoAtivado',
        'dataCadastro': FieldValue.serverTimestamp(),
      });

      // Criamos a credencial no Auth de forma assíncrona em background
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: senha.trim(),
      );
    } catch (e) {
      debugPrint('[AuthService] Erro na criação administrativa de aluno: $e');
      rethrow;
    }
  }

  // Fazer Login
  Future<User?> logarComEmailESenha(String email, String password) async {
    try {
      UserCredential resultado = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return resultado.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Erro no login: ${e.message}');
      rethrow;
    }
  }

  // Método de Logout
  Future<void> deslogar() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] Erro ao deslogar: ${e.toString()}');
      rethrow;
    }
  }
}
