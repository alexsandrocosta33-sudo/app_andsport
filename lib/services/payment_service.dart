// Os pagamentos PIX são processados exclusivamente via Cloud Functions (Firebase).
// Não há chamadas diretas à API do Mercado Pago no cliente Flutter.
// Funções utilizadas: criarPixScannerPro, criarPixAvaliacaoFisicaPro
// Token do Mercado Pago armazenado somente no Secret Manager do Firebase.

class PaymentService {
  // Classe reservada para utilitários de pagamento locais, se necessário no futuro.
  // Pagamentos reais são feitos via FirebaseFunctions.instanceFor(region:...).httpsCallable(...)
}
