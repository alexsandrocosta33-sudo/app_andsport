import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Determina a rota correta para o usuário após login ou ao reabrir o app.
///
/// Fluxo:
///   admin/professor → '/home'
///   aluno sem onboarding → '/onboarding'
///   aluno com onboarding → '/home'
class NavigationService {
  NavigationService._();

  // Admin fixo por e-mail — sempre bypass do Firestore
  static const _emailAdmin = 'alexsandrocosta33@gmail.com';

  /// Retorna a rota navegável correta para [user].
  /// Nunca lança exceção — em caso de erro retorna '/home' como fallback seguro.
  static Future<String> definirRotaInicialUsuario(User user) async {
    // Admin fixo por e-mail
    if ((user.email ?? '').toLowerCase().trim() == _emailAdmin) {
      return '/home';
    }

    try {
      final dados = await _buscarDadosUsuario(user);

      if (dados == null) {
        // Usuário não encontrado no Firestore → trata como aluno
        return await _rotaParaAluno(user.uid, dados: null);
      }

      final cargo = _determinarCargo(dados);

      if (cargo == 'admin' || cargo == 'professor') {
        return '/home';
      }

      return await _rotaParaAluno(user.uid, dados: dados);
    } catch (e) {
      debugPrint('[NavigationService] Erro ao determinar rota: $e');
      // Fallback: exibe o painel (HomeScreen cuida da autorização interna)
      return '/home';
    }
  }

  // ---------------------------------------------------------------------------
  // Privados
  // ---------------------------------------------------------------------------

  /// Busca dados do usuário: primeiro por UID, depois por e-mail como fallback.
  static Future<Map<String, dynamic>?> _buscarDadosUsuario(User user) async {
    // Tentativa 1 — documento por UID (padrão desde 2026)
    final docUid = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();

    if (docUid.exists && docUid.data() != null) {
      return docUid.data();
    }

    // Tentativa 2 — busca por e-mail (compatibilidade com documentos legados)
    final email = user.email?.trim();
    if (email == null || email.isEmpty) return null;

    final query = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return query.docs.isNotEmpty ? query.docs.first.data() : null;
  }

  /// Determina o cargo a partir dos dados Firestore.
  /// Aceita:
  ///   • campo `cargo`: 'admin' | 'professor' | 'aluno'
  ///   • legado `eProfessor`: true → 'professor', false/ausente → 'aluno'
  static String _determinarCargo(Map<String, dynamic> dados) {
    String cargo = (dados['cargo'] ?? '').toString().toLowerCase().trim();

    if (cargo.isEmpty) {
      // Campo legado
      cargo = dados['eProfessor'] == true ? 'professor' : 'aluno';
    }

    return cargo;
  }

  /// Determina a rota para um aluno verificando se o onboarding foi concluído.
  ///
  /// Ordem de verificação:
  ///   1. Campo `onboardingConcluido` no Firestore (cross-device)
  ///   2. Campo `objetivoPrincipal` no Firestore (aluno que definiu objetivo → concluído)
  ///   3. SharedPreferences com chave user-specific `onboarding_concluido_{uid}`
  ///   4. SharedPreferences com chave global legada `onboarding_concluido`
  static Future<String> _rotaParaAluno(
    String uid, {
    required Map<String, dynamic>? dados,
  }) async {
    // Verificação no Firestore (cross-device)
    if (dados != null) {
      if (dados['onboardingConcluido'] == true) return '/home';

      final objetivo = (dados['objetivoPrincipal'] ?? '').toString().trim();
      if (objetivo.isNotEmpty) return '/home';
    }

    // Verificação local (user-specific)
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool('onboarding_concluido_$uid') == true) return '/home';

    // Compatibilidade com chave global gravada pela versão anterior
    if (prefs.getBool('onboarding_concluido') == true) return '/home';

    return '/onboarding';
  }
}
