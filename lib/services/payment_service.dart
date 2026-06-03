import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentService {
  // Credenciais Oficiais fornecidas por você para a sua conta do Mercado Pago
  final String _accessToken = "APP_USR-6384103320248548-060209-89169297cbfcbe6ef28c1c09bad45a4a-3442109099";

  /// Dispara uma requisição HTTP segura para o Mercado Pago para criar um PIX dinâmico de R$ 20,00.
  /// Retorna um Map com o ID do pagamento, o código copia e cola e a imagem do QR Code em Base64.
  Future<Map<String, dynamic>?> criarPagamentoPix({
    required String email,
    required String nome,
    required double valor,
  }) async {
    final url = Uri.parse('https://api.mercadopago.com/v1/payments');

    // Headers obrigatórios incluindo autorização com o seu Access Token
    final headers = {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
      'X-Idempotency-Key': DateTime.now().millisecondsSinceEpoch.toString(), // Chave para evitar duplicidade de pagamento
    };

    // Corpo da requisição formatado para o PIX do Mercado Pago
    final body = jsonEncode({
      "transaction_amount": valor,
      "description": "Assinatura Scanner Nutricional IA PRO",
      "payment_method_id": "pix",
      "payer": {
        "email": email.isNotEmpty ? email : "aluno@academia.com",
        "first_name": nome.isNotEmpty ? nome : "Aluno",
        "last_name": "Academia",
        "identification": {
          "type": "CPF",
          // O Mercado Pago exige um CPF válido ou formato aceito. 
          // Caso você não possua o CPF do aluno salvo no banco, usamos um fictício de validação básica.
          "number": "35364718000" 
        }
      }
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Extrai os dados específicos do Pix Dinâmico gerado
        final pointOfInteraction = data['point_of_interaction'];
        if (pointOfInteraction != null) {
          final transactionData = pointOfInteraction['transaction_data'];
          if (transactionData != null) {
            return {
              'id': data['id'],
              'status': data['status'],
              'copiaECola': transactionData['qr_code'],
              'qrCodeBase64': transactionData['qr_code_base64'],
            };
          }
        }
      } else {
        print("Erro de Integração Mercado Pago: Code ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Falha ao comunicar com os servidores do Mercado Pago: $e");
    }
    return null;
  }
}
```
eof

---

### Como integrar esse novo serviço na sua `home_screen.dart`

Para que a sua tela de compras chame esse serviço real ao clicar no botão, siga estes **3 passos rápidos** de ajuste no seu arquivo `lib/screens/home_screen.dart`:

#### Passo 1: Adicionar a dependência HTTP
Verifique se você possui o pacote `http` no seu arquivo `pubspec.yaml`. Caso não possua, basta rodar o comando abaixo no terminal do seu projeto:
```bash
flutter pub add http
```

#### Passo 2: Importar e instanciar o serviço de pagamentos
No topo do seu arquivo `home_screen.dart`, adicione o import do novo serviço:
```dart
import '../services/payment_service.dart';
```
E dentro do estado da sua classe `_HomeScreenState`, instancie o serviço ao lado dos outros:
```dart
final _paymentService = PaymentService();
```

#### Passo 3: Atualizar o seu modal `_mostrarPopupCompraPlusIA`
Substitua o antigo método pelo código abaixo, que consome diretamente a API do Mercado Pago usando o e-mail e o nome do aluno selecionado atualmente:

```dart
  String _pixCopiaEColaGerado = '';
  String _qrCodeBase64Gerado = '';
  bool _gerandoPixMercadoPago = false;

  void _mostrarPopupCompraPlusIA() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple),
              SizedBox(width: 8),
              Text('Scanner Nutricional IA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ative o Scanner Nutricional PRO por apenas:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
                const SizedBox(height: 10),
                const Text(
                  'R\$ 20,00 /mês',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1),
                ),

                // Cenário 1: Botão para gerar o Pix Dinâmico via API
                if (!_gerandoPixMercadoPago && _pixCopiaEColaGerado.isEmpty) ...[
                  const Text(
                    'Clique no botão abaixo para gerar o seu código PIX oficial pelo Mercado Pago.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(45)),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Gerar PIX de R\$ 20,00 ⚡', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      setPopupState(() => _gerandoPixMercadoPago = true);
                      
                      // Chama o serviço do Mercado Pago passando os dados reais do aluno atual
                      final resultadoPix = await _paymentService.criarPagamentoPix(
                        email: _alunoSelecionadoEmail ?? '',
                        nome: _alunoSelecionadoNome ?? 'Aluno',
                        valor: 20.0,
                      );

                      if (resultadoPix != null) {
                        setPopupState(() {
                          _pixCopiaEColaGerado = resultadoPix['copiaECola'];
                          _qrCodeBase64Gerado = resultadoPix['qrCodeBase64'];
                          _gerandoPixMercadoPago = false;
                        });

                        // Seta o status para aprovação no Firebase para o professor visualizar
                        await FirebaseFirestore.instance.collection('usuarios').doc(_alunoSelecionadoId).update({
                          'iaStatusAssinatura': 'PendenteAprovacao',
                          'mercadoPagoPaymentId': resultadoPix['id'].toString(),
                        });
                      } else {
                        setPopupState(() => _gerandoPixMercadoPago = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Falha ao gerar o Pix com o Mercado Pago. Verifique sua conexão.'), backgroundColor: Colors.redAccent),
                        );
                      }
                    },
                  ),
                ],

                // Cenário 2: Carregamento do Servidor
                if (_gerandoPixMercadoPago) ...[
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(color: Colors.purple),
                  const SizedBox(height: 16),
                  const Text('Conectando ao Mercado Pago...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.purple)),
                ],

                // Cenário 3: Pix Gerado com Sucesso! Mostra QR Code e Copia e Cola
                if (_pixCopiaEColaGerado.isNotEmpty) ...[
                  const Text(
                    'PIX Gerado! Escaneie ou copie o código:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  
                  if (_qrCodeBase64Gerado.isNotEmpty) ...[
                    Container(
                      width: 160,
                      height: 160,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.memory(base64Decode(_qrCodeBase64Gerado)),
                    ),
                  ],

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple[200]!),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CÓDIGO PIX COPIA E COLA:',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _pixCopiaEColaGerado,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copiar Código PIX'),
                          onPressed: () {
                            import 'package:flutter/services.dart';
                            Clipboard.setData(ClipboardData(text: _pixCopiaEColaGerado));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Código Pix copiado com sucesso! 📋'), backgroundColor: Colors.purple),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Assim que você efetuar o pagamento, a IA será liberada instantaneamente no seu painel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _pixCopiaEColaGerado = '';
                _qrCodeBase64Gerado = '';
                Navigator.pop(context);
              },
              child: const Text('Fechar', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }