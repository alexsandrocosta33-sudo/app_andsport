import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Serviço de armazenamento local com Hive e sincronização automática com Firestore.
/// Singleton — acesse via LocalStorageService.instancia
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instancia = LocalStorageService._();

  static const _boxTreinosCache = 'treinos_cache';
  static const _boxPendentes = 'sync_pendentes';

  Box get _cache => Hive.box(_boxTreinosCache);
  Box get _pendentes => Hive.box(_boxPendentes);

  /// Inicializa o Hive. Chamar em main() antes de runApp().
  static Future<void> inicializar() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxTreinosCache);
    await Hive.openBox(_boxPendentes);
  }

  // ---------------------------------------------------------------------------
  // Cache local
  // ---------------------------------------------------------------------------

  /// Salva dados de uma ficha de treino no cache local.
  Future<void> salvarTreinoLocal({
    required String fichaId,
    required Map<String, dynamic> dados,
  }) async {
    final uid = _uidAtual;
    if (uid == null) return;
    await _cache.put('${uid}_$fichaId', jsonEncode(dados));
  }

  /// Recupera dados de uma ficha do cache local. Retorna null se não encontrado.
  Map<String, dynamic>? obterTreinoLocal(String fichaId) {
    final uid = _uidAtual;
    if (uid == null) return null;
    final json = _cache.get('${uid}_$fichaId');
    if (json == null) return null;
    return jsonDecode(json as String) as Map<String, dynamic>;
  }

  /// Remove uma entrada do cache local.
  Future<void> removerTreinoLocal(String fichaId) async {
    final uid = _uidAtual;
    if (uid == null) return;
    await _cache.delete('${uid}_$fichaId');
  }

  /// Limpa todo o cache de treinos do usuário atual.
  Future<void> limparCacheLocal() async {
    final uid = _uidAtual;
    if (uid == null) return;
    final chavesUsuario = _cache.keys
        .where((k) => k.toString().startsWith('${uid}_'))
        .toList();
    await _cache.deleteAll(chavesUsuario);
  }

  // ---------------------------------------------------------------------------
  // Fila de sincronização offline
  // ---------------------------------------------------------------------------

  /// Enfileira uma operação para sincronizar com Firestore quando a conexão voltar.
  Future<void> enfileirarParaSincronizacao({
    required String colecao,
    required String docId,
    required Map<String, dynamic> dados,
  }) async {
    final uid = _uidAtual;
    if (uid == null) return;

    final chave = '${DateTime.now().millisecondsSinceEpoch}_$docId';
    await _pendentes.put(
      chave,
      jsonEncode({
        'uid': uid,
        'colecao': colecao,
        'docId': docId,
        'dados': dados,
        'criadoEm': DateTime.now().toIso8601String(),
      }),
    );
    debugPrint('[LocalStorage] Enfileirado para sync: $colecao/$docId');
  }

  /// Tenta sincronizar todos os itens pendentes com o Firestore.
  /// Retorna o número de itens sincronizados com sucesso.
  Future<int> sincronizarComFirestore() async {
    if (_pendentes.isEmpty) return 0;

    final conectado = await _verificarConexao();
    if (!conectado) {
      debugPrint('[LocalStorage] Sem conexão — sync adiado.');
      return 0;
    }

    final firestore = FirebaseFirestore.instance;
    final chaves = _pendentes.keys.toList();
    int sincronizados = 0;

    for (final chave in chaves) {
      try {
        final json = _pendentes.get(chave) as String?;
        if (json == null) continue;

        final item = jsonDecode(json) as Map<String, dynamic>;
        final colecao = item['colecao'] as String;
        final docId = item['docId'] as String;
        final dados = Map<String, dynamic>.from(item['dados'] as Map);

        await firestore
            .collection(colecao)
            .doc(docId)
            .set(dados, SetOptions(merge: true));

        await _pendentes.delete(chave);
        sincronizados++;
        debugPrint('[LocalStorage] Sincronizado: $colecao/$docId');
      } catch (e) {
        debugPrint('[LocalStorage] Erro ao sincronizar $chave: $e');
      }
    }

    return sincronizados;
  }

  /// Inicia monitoramento de conectividade para sync automático.
  /// Chamar após inicializar() quando o app estiver pronto.
  void iniciarSincronizacaoAutomatica() {
    Connectivity().onConnectivityChanged.listen((results) {
      final conectado = results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);
      if (conectado) {
        sincronizarComFirestore();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? get _uidAtual => FirebaseAuth.instance.currentUser?.uid;

  int get quantidadePendentes => _pendentes.length;

  Future<bool> _verificarConexao() async {
    final results = await Connectivity().checkConnectivity();
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  }
}
