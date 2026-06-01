const functions = require("firebase-functions");
const https = require("https");

exports.gerarConteudoGemini = functions.https.onCall((data, context) => {
  const prompt = data.prompt;

  if (!prompt) {
    throw new functions.https.HttpsError("invalid-argument", "O prompt não pode estar vazio.");
  }

  // Chave corporativa estável
  const apiKey = "AQ.Ab8RN6LdNCvzQEinjHXqhuiBPMs9fyO198x6iHrlawP0glwIEw";
  
  // Número do projeto correto (academiaandsport)
  const projectIdNum = "375712346134";

  // Endpoint oficial e direto da Vertex AI
  const url = `https://us-central1-aiplatform.googleapis.com/v1/projects/${projectIdNum}/locations/us-central1/publishers/google/models/gemini-1.5-flash:generateContent`;

  const bodyData = JSON.stringify({
    contents: [{ role: "user", parts: [{ text: prompt }] }]
  });

  return new Promise((resolve, reject) => {
    const req = https.request(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
        "Content-Length": Buffer.byteLength(bodyData)
      }
    }, (res) => {
      let responseBody = "";
      res.on("data", (chunk) => { responseBody += chunk; });
      
      res.on("end", () => {
        try {
          const parsedData = JSON.parse(responseBody);
          if (res.statusCode === 200) {
            resolve({ text: parsedData.candidates[0].content.parts[0].text });
          } else {
            reject(new functions.https.HttpsError("internal", `Erro Vertex API (${res.statusCode}): ${responseBody}`));
          }
        } catch (e) {
          reject(new functions.https.HttpsError("internal", "Erro ao processar resposta do servidor."));
        }
      });
    });

    req.on("error", (error) => {
      reject(new functions.https.HttpsError("internal", `Erro na conexao: ${error.message}`));
    });

    req.write(bodyData);
    req.end();
  });
});