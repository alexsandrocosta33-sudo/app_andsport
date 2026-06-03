const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const { MercadoPagoConfig, Payment } = require("mercadopago");

admin.initializeApp();

const db = admin.firestore();

const MERCADOPAGO_ACCESS_TOKEN = defineSecret("MERCADOPAGO_ACCESS_TOKEN");

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

    const vencimento = new Date(Date.now() + 5 * 60 * 1000);

    const referenciaExterna = `scanner_pro_${alunoId}_${Date.now()}`;

    try {
      const pagamento = await payment.create({
        body: {
          transaction_amount: 20.0,
          description: "Scanner Nutricional PRO - AndSport",
          payment_method_id: "pix",
          external_reference: referenciaExterna,
          date_of_expiration: vencimento.toISOString(),
          payer: {
            email: emailAluno,
          },
        },
        requestOptions: {
          idempotencyKey: referenciaExterna,
        },
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
        valor: 20.0,
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
      };
    } catch (error) {
      console.error("Erro ao criar PIX Mercado Pago:", error);
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

    const pagamentoId = request.data.pagamentoId;

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

      await db.collection("pagamentos_scanner_ia").doc(pagamentoId.toString()).set(
        {
          status,
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      if (status === "approved") {
        await liberarScannerPro(dadosPagamento.alunoId, pagamentoId.toString());
      }

      return {
        status,
        aprovado: status === "approved",
      };
    } catch (error) {
      console.error("Erro ao consultar pagamento:", error);
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

      if (!paymentId) {
        console.log("Webhook recebido sem paymentId:", req.query, req.body);
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

      await db.collection("pagamentos_scanner_ia").doc(paymentId.toString()).set(
        {
          status,
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
      console.error("Erro no webhook Mercado Pago:", error);
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