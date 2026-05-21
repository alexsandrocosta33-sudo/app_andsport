import 'package:cloud_firestore/cloud_firestore.dart';

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
      print("Erro ao atualizar status financeiro: $e");
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
  Stream<QuerySnapshot> listarTreinosPorFicha(String alunoId, String ficha) {
    return _db
        .collection('usuarios')
        .doc(alunoId)
        .collection('treinos')
        .where('ficha', isEqualTo: ficha.toUpperCase().trim())
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
        'dataCriacao': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Erro ao salvar treino: $e");
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
      print("Erro ao excluir treino: $e");
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
      print("Erro ao concluir treino: $e");
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
  // AUXILIARES
  // =========================================================================

  /// Garante que strings vazias ou nulas não quebrem o banco, limpando espaços desnecessários
  String _ajustarTexto(String texto) {
    if (texto.trim().isEmpty) return '---';
    return texto.trim();
  }
}
