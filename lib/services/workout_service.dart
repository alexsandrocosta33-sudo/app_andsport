import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WorkoutService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================================================================
  // MÓDULO FINANCEIRO (NOVA ATUALIZAÇÃO)
  // =========================================================================

  /// Atualiza os dados de mensalidade, vencimento e status de pagamento do aluno
  Future<void> atualizarStatusFinanceiro({
    required String alunoId,
    required double mensalidade,
    required int vencimento,
    required String status,
  }) async {
    try {
      await _db.collection('usuarios').doc(alunoId).update({
        'valorMensalidade': mensalidade,
        'diaVencimento': vencimento,
        'statusPagamento': status, // 'Pago', 'Pendente' ou 'Atrasado'
      });
    } catch (e) {
      debugPrint("[WorkoutService] Erro ao atualizar status financeiro: $e");
      rethrow;
    }
  }

  // =========================================================================
  // MÓDULO DE TREINOS E ALUNOS (FLUXO ORIGINAL)
  // =========================================================================

  /// Retorna um Stream em tempo real com todos os usuários cadastrados
  Stream<QuerySnapshot> listarTodosAlunos() {
    return _db.collection('usuarios').snapshots();
  }

  /// Escuta os treinos em tempo real filtrados pela Ficha e pelo ID do Aluno correto
  Stream<QuerySnapshot> listarTreinosPorFicha(
    String alunoId,
    String ficha,
  ) {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(alunoId)
        .collection('treinos')
        .where('ficha', isEqualTo: ficha)
        .snapshots();
  }

  /// Salva ou atualiza um exercício dentro da subcoleção de treinos do aluno
  Future<void> salvarTreino({
    required String alunoId,
    required String ficha,
    required String grupoMuscular,
    required String nomeExercicios,
    required String seriesRepeticoes,
    required String carga,
    required String videoUrl,
  }) async {
    try {
      // Cria ou atualiza o documento com chaves consistentes para a interface
      await _db.collection('usuarios').doc(alunoId).collection('treinos').add({
        'ficha': _ajustarTexto(ficha),
        'grupo': _ajustarTexto(grupoMuscular),
        'exercicios': _ajustarTexto(nomeExercicios),
        'series': _ajustarTexto(seriesRepeticoes),
        'carga': _ajustarTexto(carga),
        'videoUrl': videoUrl.trim(),
        'criadoEm': FieldValue.serverTimestamp(),
        'dataCriacao': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("[WorkoutService] Erro ao salvar treino: $e");
      rethrow;
    }
  }

  /// Exclui um exercício específico da ficha do aluno
  Future<void> excluirTreino(String alunoId, String treinoId) async {
    try {
      await _db
          .collection('usuarios')
          .doc(alunoId)
          .collection('treinos')
          .doc(treinoId)
          .delete();
    } catch (e) {
      debugPrint("[WorkoutService] Erro ao excluir treino: $e");
      rethrow;
    }
  }

  /// Registra um exercício concluído na subcoleção de histórico do aluno
  Future<void> concluirTreino(
    String alunoId,
    String grupo,
    String exercicio,
  ) async {
    try {
      await _db
          .collection('usuarios')
          .doc(alunoId)
          .collection('historico')
          .add({
            'grupo': _ajustarTexto(grupo),
            'exercicio': _ajustarTexto(exercicio),
            'dataConclusao': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint("[WorkoutService] Erro ao concluir treino: $e");
      rethrow;
    }
  }

  /// Lista o histórico de treinos concluídos pelo aluno
  Stream<QuerySnapshot> listarHistorico(String alunoId) {
    return _db
        .collection('usuarios')
        .doc(alunoId)
        .collection('historico')
        .orderBy('dataConclusao', descending: true)
        .limit(20) // Limita aos últimos 20 para otimizar desempenho
        .snapshots();
  }

  // =========================================================================
  // MÓDULO TREINOS PADRÃO (dinâmico por nível e perfil)
  // Coleção: treinos_padrao/{modeloId}/exercicios
  // =========================================================================

  /// Gera o ID do documento no Firestore: ex. 'iniciante_feminino', 'avancado_masculino'
  static String gerarModeloId(String nivel, String perfil) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll('á', 'a').replaceAll('à', 'a').replaceAll('ã', 'a')
        .replaceAll('â', 'a').replaceAll('é', 'e').replaceAll('ê', 'e')
        .replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ô', 'o')
        .replaceAll('ú', 'u').replaceAll('ü', 'u').replaceAll('ç', 'c');
    return '${norm(nivel)}_${norm(perfil)}';
  }

  /// Stream em tempo real dos exercícios de um modelo padrão
  Stream<QuerySnapshot> listarExerciciosPadrao(String modeloId) {
    return _db
        .collection('treinos_padrao')
        .doc(modeloId)
        .collection('exercicios')
        .orderBy('criadoEm')
        .snapshots();
  }

  /// Verifica se o modelo tem pelo menos um exercício cadastrado
  Future<bool> modeloPadraoExiste(String modeloId) async {
    try {
      final snap = await _db
          .collection('treinos_padrao')
          .doc(modeloId)
          .collection('exercicios')
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Cria ou edita um exercício dentro de um modelo padrão
  Future<void> salvarExercicioPadrao(
    String modeloId,
    Map<String, dynamic> dados, {
    String? exercicioId,
  }) async {
    final col = _db
        .collection('treinos_padrao')
        .doc(modeloId)
        .collection('exercicios');

    final dadosComTimestamp = {
      ...dados,
      'atualizadoEm': FieldValue.serverTimestamp(),
    };

    if (exercicioId != null) {
      await col.doc(exercicioId).set(dadosComTimestamp, SetOptions(merge: true));
    } else {
      await col.add({...dadosComTimestamp, 'criadoEm': FieldValue.serverTimestamp()});
    }
  }

  /// Exclui um exercício de um modelo padrão
  Future<void> excluirExercicioPadrao(String modeloId, String exercicioId) async {
    await _db
        .collection('treinos_padrao')
        .doc(modeloId)
        .collection('exercicios')
        .doc(exercicioId)
        .delete();
  }

  /// Popula um modelo padrão no Firestore com uma lista de exercícios base
  Future<void> popularModeloInicial(
    String nivel,
    String perfil,
    List<Map<String, String>> exercicios,
  ) async {
    final modeloId = gerarModeloId(nivel, perfil);
    final docRef = _db.collection('treinos_padrao').doc(modeloId);

    await docRef.set({
      'nivel': nivel,
      'perfil': perfil,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final col = docRef.collection('exercicios');

    for (int i = 0; i < exercicios.length; i++) {
      final ex = exercicios[i];
      await col.add({
        'ficha': ex['ficha'] ?? 'A',
        'grupo': ex['grupo'] ?? 'Peito',
        'exercicio': ex['exercicio'] ?? '',
        'series': ex['series'] ?? '3x12',
        'carga': ex['carga'] ?? '---',
        'videoUrl': ex['videoUrl'] ?? '---',
        'ordem': i + 1,
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
    }
  }

  // =========================================================================
  // COMPATIBILIDADE CAMINHO ANTIGO (alunos/.../fichas_treino)
  // =========================================================================

  /// Normaliza campos de documento antigo para o formato novo
  static Map<String, dynamic> normalizarDocumentoTreinoAntigo(
    Map<String, dynamic> dados,
  ) {
    return {
      'ficha': (dados['ficha'] ?? 'A').toString().toUpperCase().trim(),
      'grupo': (dados['grupo'] ?? dados['grupoMuscular'] ?? '').toString().trim(),
      'exercicios': (dados['exercicios'] ??
              dados['exercicio'] ??
              dados['nomeExercicio'] ??
              dados['nome'] ??
              '')
          .toString()
          .trim(),
      'series': (dados['series'] ?? dados['seriesRepeticoes'] ?? '').toString().trim(),
      'carga': (dados['carga'] ?? dados['peso'] ?? '---').toString().trim(),
      'videoUrl': (dados['videoUrl'] ?? dados['linkVideo'] ?? '---').toString().trim(),
    };
  }

  /// Busca treinos no caminho antigo (alunos/{candidato}/fichas_treino)
  /// Tenta múltiplos candidatos derivados de ID, nome e e-mail.
  /// Retorna {'docId': String, 'treinos': List<Map>} ou null.
  Future<Map<String, dynamic>?> buscarTreinosAntigos({
    required String alunoId,
    String? alunoNome,
    String? email,
  }) async {
    final candidatos = <String>[];

    void add(String? s) {
      if (s == null || s.isEmpty) return;
      final v = s.trim();
      if (!candidatos.contains(v)) candidatos.add(v);
    }

    add(alunoId);
    if (alunoNome != null) {
      add(alunoNome.toLowerCase().trim());
      add(alunoNome.trim());
      add(alunoNome.toLowerCase().replaceAll(' ', ''));
      add(alunoNome.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áàãâéêíóôúüç]'), ''));
    }
    if (email != null) {
      add(email.split('@').first.toLowerCase().trim());
    }

    for (final candidato in candidatos) {
      try {
        final snap = await _db
            .collection('alunos')
            .doc(candidato)
            .collection('fichas_treino')
            .get();

        if (snap.docs.isNotEmpty) {
          final treinos = snap.docs.map((doc) {
            final d = doc.data();
            return {'__id': doc.id, ...normalizarDocumentoTreinoAntigo(d)};
          }).toList();
          return {'docId': candidato, 'treinos': treinos};
        }
      } catch (_) {
        // candidato não encontrado ou sem permissão — tenta o próximo
      }
    }
    return null;
  }

  /// Copia treinos do caminho antigo para o novo, sem apagar e sem duplicar.
  /// Retorna o número de exercícios efetivamente migrados.
  Future<int> migrarTreinosAntigos({
    required String alunoId,
    required String docIdAntigo,
  }) async {
    final snapAntigos = await _db
        .collection('alunos')
        .doc(docIdAntigo)
        .collection('fichas_treino')
        .get();

    if (snapAntigos.docs.isEmpty) return 0;

    final snapNovos = await _db
        .collection('usuarios')
        .doc(alunoId)
        .collection('treinos')
        .get();

    // Assinatura de unicidade: ficha|grupo|nome
    final assinaturas = <String>{};
    for (final doc in snapNovos.docs) {
      final d = doc.data();
      final sig =
          '${d['ficha']}|${(d['grupo'] ?? '').toString().toLowerCase()}|${(d['exercicios'] ?? '').toString().toLowerCase().trim()}';
      assinaturas.add(sig);
    }

    int migrados = 0;
    final col = _db.collection('usuarios').doc(alunoId).collection('treinos');

    for (final docAntigo in snapAntigos.docs) {
      final d = docAntigo.data();
      final norm = normalizarDocumentoTreinoAntigo(d);
      final sig =
          '${norm['ficha']}|${norm['grupo'].toLowerCase()}|${norm['exercicios'].toString().toLowerCase().trim()}';

      if (!assinaturas.contains(sig)) {
        await col.add({
          ...norm,
          'criadoEm': d['criadoEm'] ?? FieldValue.serverTimestamp(),
          'dataCriacao': d['criadoEm'] ?? FieldValue.serverTimestamp(),
          'migradoDe': 'alunos/$docIdAntigo/fichas_treino/${docAntigo.id}',
        });
        assinaturas.add(sig);
        migrados++;
      }
    }
    return migrados;
  }

  // =========================================================================
  // AUXILIARES
  // =========================================================================

  /// Garante que strings vazias ou nulas não quebrem o banco, limpando espaços desnecessários
  String _ajustarTexto(String texto) {
    if (texto.trim().isEmpty) return '---';
    return texto.trim();
  }
}
