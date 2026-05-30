const functions = require("firebase-functions");
const axios = require("axios");

exports.gerarConteudoGemini = functions.https.onCall(async (data, context) => {
  // Sua chave AQ corporativa fica 100% protegida e invisível aqui no servidor
  const apiKey = 'AQ.Ab8RN6LdNCvzQEinjHXqhuiBPMs9fyO198x6iHrlawP0glwIEw';
  const projectIdNum = '1054648561946';
  
  const prompt = data.prompt;

  if (!prompt) {
    throw new functions.https.HttpsError('invalid-argument', 'O prompt não pode estar vazio.');
  }

  // Rota oficial da Vertex AI para chaves estruturadas do tipo AQ.
  const url = `https://us-central1-aiplatform.googleapis.com/v1/projects/${projectIdNum}/locations/us-central1/publishers/google/models/gemini-1.5-flash:generateContent`;

  try {
    const response = await axios.post(
      url,
      {
        contents: [
          {
            role: 'user',
            parts: [{ text: prompt }],
          },
        ],
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
      }
    );

    if (response.status === 200) {
      return { text: response.data.candidates[0].content.parts[0].text };
    } else {
      throw new functions.https.HttpsError('internal', 'Erro na resposta do Gemini.');
    }
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});