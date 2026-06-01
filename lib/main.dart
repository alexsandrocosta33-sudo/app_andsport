import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
// CORREÇÃO: Importamos a nova página que você acabou de criar
import 'screens/gerador_treino_ia_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academia AndSport',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      // AJUSTE: Mudamos o ponto de partida para abrir direto no gerador automático
      initialRoute: '/login',

      // Mapeamos os caminhos do aplicativo incluindo a nova rota
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        // ADICIONADO: Rota temporária para o nosso teste de automação do banco
        '/gerador_ia': (context) => const GeradorTreinoIAPage(),
      },
    );
  }
}
