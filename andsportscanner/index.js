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

// Avaliação Física PRO / Medições corporais com IA
const VALOR_AVALIACAO_FISICA_PRO = 19.9;

// Combo Performance IA: Scanner Nutricional + Avaliação Física PRO
const VALOR_COMBO_PERFORMANCE_IA = 29.9;

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

// =======================================================
// AVALIAÇÃO FÍSICA PRO / MEDIÇÕES CORPORAIS COM IA
// =======================================================
// Tipos aceitos no app Flutter:
// - "avaliacao_fisica_pro" => R$ 19,90 / mês
// - "combo_performance_ia" => R$ 29,90 / mês
//
// Coleções usadas:
// pagamentos_avaliacao_fisica_ia
//
// Campos liberados no usuário:
// avaliacaoFisicaStatusAssinatura
// planoAvaliacaoFisica
// valorAvaliacaoFisica
// dataInicioAvaliacaoFisica
// dataFimAvaliacaoFisica
// avaliacaoFisicaIAMesReferencia
// avaliacaoFisicaIAUsosMes
//
// No combo, também libera o Scanner Nutricional PRO.

exports.criarPixAvaliacaoFisicaPro = onCall(
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

    const tipoPlanoRecebido = request.data?.tipoPlano || "avaliacao_fisica_pro";

    let tipoPlano = "avaliacao_fisica_pro";
    let valor = VALOR_AVALIACAO_FISICA_PRO;
    let descricao = "Evolução Física PRO com IA - AndSport";
    let nomePlano = "Evolução Física PRO";

    if (tipoPlanoRecebido === "combo_performance_ia") {
      tipoPlano = "combo_performance_ia";
      valor = VALOR_COMBO_PERFORMANCE_IA;
      descricao = "Combo Performance IA - Scanner + Evolução Física - AndSport";
      nomePlano = "Combo Performance IA";
    }

    const token = MERCADOPAGO_ACCESS_TOKEN.value();

    const client = new MercadoPagoConfig({
      accessToken: token,
    });

    const payment = new Payment(client);

    const vencimento = new Date(Date.now() + 15 * 60 * 1000);
    const referenciaExterna = `${tipoPlano}_${alunoId}_${Date.now()}`;

    try {
      const pagamento = await payment.create({
        body: {
          transaction_amount: valor,
          description: descricao,
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

      console.log("PIX Avaliação Física/Combo criado Mercado Pago:", {
        id: pagamento.id,
        status: pagamento.status,
        status_detail: pagamento.status_detail,
        transaction_amount: pagamento.transaction_amount,
        external_reference: pagamento.external_reference,
        tipoPlano,
        nomePlano,
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

      await db.collection("pagamentos_avaliacao_fisica_ia").doc(pagamentoId).set({
        alunoId,
        emailAluno,
        mercadoPagoPaymentId: pagamentoId,
        externalReference: referenciaExterna,
        status: pagamento.status || "pending",
        statusDetail: pagamento.status_detail || "---",
        valor,
        tipoPlano,
        nomePlano,
        qrCode,
        qrCodeBase64,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        expiraEm: admin.firestore.Timestamp.fromDate(vencimento),
      });

      await db.collection("usuarios").doc(alunoId).set(
        {
          avaliacaoFisicaStatusAssinatura: "AguardandoPagamento",
          pagamentoAvaliacaoFisicaAtualId: pagamentoId,
          planoAvaliacaoFisica: nomePlano,
          valorAvaliacaoFisica: valor,
          dataPedidoPagamentoAvaliacaoFisica:
            admin.firestore.FieldValue.serverTimestamp(),
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
        tipoPlano,
        nomePlano,
        valor,
      };
    } catch (error) {
      console.error("Erro ao criar PIX Avaliação Física/Combo:", {
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

exports.consultarStatusPixAvaliacaoFisicaPro = onCall(
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
      .collection("pagamentos_avaliacao_fisica_ia")
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

      console.log("Status Avaliação Física/Combo consultado:", {
        id: pagamento.id,
        status,
        status_detail: statusDetail,
        transaction_amount: pagamento.transaction_amount,
        date_created: pagamento.date_created,
        date_approved: pagamento.date_approved,
        date_last_updated: pagamento.date_last_updated,
        external_reference: pagamento.external_reference,
        tipoPlano: dadosPagamento.tipoPlano,
        nomePlano: dadosPagamento.nomePlano,
      });

      await db
        .collection("pagamentos_avaliacao_fisica_ia")
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
        await liberarAvaliacaoFisicaPro(
          dadosPagamento.alunoId,
          pagamentoId.toString(),
          dadosPagamento.tipoPlano || "avaliacao_fisica_pro",
          dadosPagamento.valor || VALOR_AVALIACAO_FISICA_PRO
        );
      }

      return {
        status,
        statusDetail,
        aprovado: status === "approved",
      };
    } catch (error) {
      console.error("Erro ao consultar PIX Avaliação Física/Combo:", {
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

exports.webhookMercadoPagoAvaliacaoFisicaPro = onRequest(
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

      console.log("Webhook Avaliação Física/Combo recebido:", {
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

      console.log("Pagamento Avaliação Física/Combo recebido no webhook:", {
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
        .collection("pagamentos_avaliacao_fisica_ia")
        .doc(paymentId.toString())
        .get();

      if (!pagamentoDoc.exists) {
        console.log("Pagamento Avaliação Física/Combo não encontrado:", paymentId);
        res.status(200).send("pagamento não encontrado");
        return;
      }

      const dados = pagamentoDoc.data();

      await db
        .collection("pagamentos_avaliacao_fisica_ia")
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
        await liberarAvaliacaoFisicaPro(
          dados.alunoId,
          paymentId.toString(),
          dados.tipoPlano || "avaliacao_fisica_pro",
          dados.valor || VALOR_AVALIACAO_FISICA_PRO
        );
      }

      res.status(200).send("ok");
    } catch (error) {
      console.error("Erro no webhook Avaliação Física/Combo:", {
        message: error.message,
        status: error.status,
        cause: error.cause,
        error,
      });

      res.status(200).send("erro tratado");
    }
  }
);

async function liberarAvaliacaoFisicaPro(alunoId, pagamentoId, tipoPlano, valor) {
  const agora = admin.firestore.Timestamp.now();
  const dataFim = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
  );

  const dataAtual = new Date();
  const mesReferencia = `${dataAtual.getFullYear()}-${String(
    dataAtual.getMonth() + 1
  ).padStart(2, "0")}`;

  const isCombo = tipoPlano === "combo_performance_ia";
  const nomePlano = isCombo ? "Combo Performance IA" : "Evolução Física PRO";
  const limiteAnalises = isCombo ? 8 : 4;

  const dadosLiberacao = {
    avaliacaoFisicaStatusAssinatura: "Ativo",
    planoAvaliacaoFisica: nomePlano,
    valorAvaliacaoFisica: valor,
    dataInicioAvaliacaoFisica: agora,
    dataFimAvaliacaoFisica: dataFim,
    pagamentoAvaliacaoFisicaLiberadoId: pagamentoId,
    pagamentoAvaliacaoFisicaAtualId: pagamentoId,
    avaliacaoFisicaIAMesReferencia: mesReferencia,
    avaliacaoFisicaIAUsosMes: 0,
    avaliacaoFisicaIALimiteMes: limiteAnalises,
    atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (isCombo) {
    dadosLiberacao.iaStatusAssinatura = "Ativo";
    dadosLiberacao.dataInicioIA = agora;
    dadosLiberacao.dataFimIA = dataFim;
    dadosLiberacao.pagamentoScannerLiberadoId = pagamentoId;
    dadosLiberacao.pagamentoScannerAtualId = pagamentoId;
    dadosLiberacao.planoPerformanceIA = "Combo Performance IA";
  }

  await db.collection("usuarios").doc(alunoId).set(dadosLiberacao, {
    merge: true,
  });

  await db.collection("pagamentos_avaliacao_fisica_ia").doc(pagamentoId).set(
    {
      avaliacaoFisicaLiberada: true,
      comboPerformanceLiberado: isCombo,
      liberadoEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  if (isCombo) {
    await db.collection("pagamentos_scanner_ia").doc(pagamentoId).set(
      {
        alunoId,
        valor,
        status: "approved",
        statusDetail: "combo_performance_ia_liberado",
        scannerLiberado: true,
        liberadoViaCombo: true,
        liberadoEm: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
}
