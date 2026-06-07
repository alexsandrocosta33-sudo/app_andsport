const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { MercadoPagoConfig, Payment } = require("mercadopago");

admin.initializeApp();

const db = admin.firestore();
const MERCADOPAGO_ACCESS_TOKEN = defineSecret("MERCADOPAGO_ACCESS_TOKEN");

// Para teste, pode usar 1.0.
// Quando validar tudo, volte para 20.0.
const VALOR_SCANNER_PRO = 20.0;

exports.criarPixScannerPro = onCall(
  {
    region: "southamerica-east1",
    secrets: [MERCADOPAGO_ACCESS_TOKEN],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Usuário precisa estar logado para gerar PIX."
      );
    }

    const alunoId = request.auth.uid;
    const emailAluno =
      request.auth.token.email || `aluno_${alunoId}@andsport.com`;

    const token = MERCADOPAGO_ACCESS_TOKEN.value();

    const client = new MercadoPagoConfig({
      accessToken: token,
    });

    const payment = new Payment(client);

    // Antes estava 5 minutos. Para Pix via banco, 15 minutos é mais seguro.
    const vencimento = new Date(Date.now() + 15 * 60 * 1000);

    const referenciaExterna = `scanner_pro_${alunoId}_${Date.now()}`;

    try {
      const pagamento = await payment.create({
        body: {
          transaction_amount: VALOR_SCANNER_PRO,
          description: "Scanner Nutricional PRO - AndSport",
          payment_method_id: "pix",
          external_reference: referenciaExterna,
          date_of_expiration: vencimento.toISOString(),
          payer: {
            email: emailAluno,
            first_name: "Aluno",
            last_name: "AndSport",
          },
        },
        requestOptions: {
          idempotencyKey: referenciaExterna,
        },
      });

      console.log("PIX criado Mercado Pago:", {
        id: pagamento.id,
        status: pagamento.status,
        status_detail: pagamento.status_detail,
        transaction_amount: pagamento.transaction_amount,
        external_reference: pagamento.external_reference,
        date_of_expiration: pagamento.date_of_expiration,
        qr_code_gerado:
          pagamento.point_of_interaction?.transaction_data?.qr_code ? "SIM" : "NAO",
      });

      const qrCode =
        pagamento.point_of_interaction?.transaction_data?.qr_code || "";

      const qrCodeBase64 =
        pagamento.point_of_interaction?.transaction_data?.qr_code_base64 || "";

      const pagamentoId = pagamento.id?.toString();

      if (!pagamentoId || !qrCode) {
        throw new Error("Mercado Pago não retornou QR Code válido.");
      }

      await db.collection("pagamentos_scanner_ia").doc(pagamentoId).set({
        alunoId,
        emailAluno,
        mercadoPagoPaymentId: pagamentoId,
        externalReference: referenciaExterna,
        status: pagamento.status || "pending",
        statusDetail: pagamento.status_detail || "---",
        valor: VALOR_SCANNER_PRO,
        qrCode,
        qrCodeBase64,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        expiraEm: admin.firestore.Timestamp.fromDate(vencimento),
      });

      await db.collection("usuarios").doc(alunoId).set(
        {
          iaStatusAssinatura: "AguardandoPagamento",
          pagamentoScannerAtualId: pagamentoId,
          dataPedidoPagamentoIA: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        pagamentoId,
        qrCode,
        qrCodeBase64,
        expiraEm: vencimento.toISOString(),
        status: pagamento.status || "pending",
        statusDetail: pagamento.status_detail || "---",
      };
    } catch (error) {
      console.error("Erro ao criar PIX Mercado Pago:", {
        message: error.message,
        status: error.status,
        cause: error.cause,
        error,
      });

      throw new HttpsError(
        "internal",
        "Não foi possível criar o PIX. Tente novamente."
      );
    }
  }
);

exports.consultarStatusPixScannerPro = onCall(
  {
    region: "southamerica-east1",
    secrets: [MERCADOPAGO_ACCESS_TOKEN],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Usuário precisa estar logado."
      );
    }

    const pagamentoId = request.data?.pagamentoId;

    if (!pagamentoId) {
      throw new HttpsError(
        "invalid-argument",
        "pagamentoId é obrigatório."
      );
    }

    const docPagamento = await db
      .collection("pagamentos_scanner_ia")
      .doc(pagamentoId.toString())
      .get();

    if (!docPagamento.exists) {
      throw new HttpsError("not-found", "Pagamento não encontrado.");
    }

    const dadosPagamento = docPagamento.data();

    if (dadosPagamento.alunoId !== request.auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "Esse pagamento não pertence ao aluno logado."
      );
    }

    const token = MERCADOPAGO_ACCESS_TOKEN.value();

    const client = new MercadoPagoConfig({
      accessToken: token,
    });

    const payment = new Payment(client);

    try {
      const pagamento = await payment.get({
        id: pagamentoId.toString(),
      });

      const status = pagamento.status || "unknown";
      const statusDetail = pagamento.status_detail || "---";

      console.log("Status Mercado Pago consultado:", {
        id: pagamento.id,
        status,
        status_detail: statusDetail,
        transaction_amount: pagamento.transaction_amount,
        date_created: pagamento.date_created,
        date_approved: pagamento.date_approved,
        date_last_updated: pagamento.date_last_updated,
        external_reference: pagamento.external_reference,
      });

      await db
        .collection("pagamentos_scanner_ia")
        .doc(pagamentoId.toString())
        .set(
          {
            status,
            statusDetail,
            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      if (status === "approved") {
        await liberarScannerPro(dadosPagamento.alunoId, pagamentoId.toString());
      }

      return {
        status,
        statusDetail,
        aprovado: status === "approved",
      };
    } catch (error) {
      console.error("Erro ao consultar pagamento:", {
        message: error.message,
        status: error.status,
        cause: error.cause,
        error,
      });

      throw new HttpsError(
        "internal",
        "Não foi possível consultar o status do PIX."
      );
    }
  }
);

exports.webhookMercadoPagoScannerPro = onRequest(
  {
    region: "southamerica-east1",
    secrets: [MERCADOPAGO_ACCESS_TOKEN],
  },
  async (req, res) => {
    try {
      const paymentId =
        req.query["data.id"] ||
        req.query.id ||
        req.body?.data?.id ||
        req.body?.id;

      const type = req.query.type || req.body?.type || req.body?.topic;

      console.log("Webhook Mercado Pago recebido:", {
        query: req.query,
        body: req.body,
        paymentId,
        type,
      });

      if (!paymentId) {
        console.log("Webhook recebido sem paymentId.");
        res.status(200).send("sem paymentId");
        return;
      }

      if (type && type !== "payment") {
        res.status(200).send("evento ignorado");
        return;
      }

      const token = MERCADOPAGO_ACCESS_TOKEN.value();

      const client = new MercadoPagoConfig({
        accessToken: token,
      });

      const payment = new Payment(client);

      const pagamento = await payment.get({
        id: paymentId.toString(),
      });

      const status = pagamento.status || "unknown";
      const statusDetail = pagamento.status_detail || "---";

      console.log("Pagamento recebido no webhook:", {
        id: pagamento.id,
        status,
        status_detail: statusDetail,
        transaction_amount: pagamento.transaction_amount,
        date_created: pagamento.date_created,
        date_approved: pagamento.date_approved,
        date_last_updated: pagamento.date_last_updated,
        external_reference: pagamento.external_reference,
      });

      const pagamentoDoc = await db
        .collection("pagamentos_scanner_ia")
        .doc(paymentId.toString())
        .get();

      if (!pagamentoDoc.exists) {
        console.log("Pagamento não encontrado no Firestore:", paymentId);
        res.status(200).send("pagamento não encontrado");
        return;
      }

      const dados = pagamentoDoc.data();

      await db
        .collection("pagamentos_scanner_ia")
        .doc(paymentId.toString())
        .set(
          {
            status,
            statusDetail,
            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
            webhookRecebidoEm: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      if (status === "approved") {
        await liberarScannerPro(dados.alunoId, paymentId.toString());
      }

      res.status(200).send("ok");
    } catch (error) {
      console.error("Erro no webhook Mercado Pago:", {
        message: error.message,
        status: error.status,
        cause: error.cause,
        error,
      });

      res.status(200).send("erro tratado");
    }
  }
);

async function liberarScannerPro(alunoId, pagamentoId) {
  const agora = admin.firestore.Timestamp.now();
  const dataFim = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
  );

  await db.collection("usuarios").doc(alunoId).set(
    {
      iaStatusAssinatura: "Ativo",
      dataInicioIA: agora,
      dataFimIA: dataFim,
      pagamentoScannerLiberadoId: pagamentoId,
      pagamentoScannerAtualId: pagamentoId,
      atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await db.collection("pagamentos_scanner_ia").doc(pagamentoId).set(
    {
      scannerLiberado: true,
      liberadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}