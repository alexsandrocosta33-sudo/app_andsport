import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/gerador_treino_ia_page.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/navigation_service.dart';
import 'services/notification_service.dart';
import 'services/local_storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializa serviços de suporte
  await LocalStorageService.inicializar();
  await NotificationService.instancia.inicializar();

  // Aguarda o Firebase Auth restaurar a sessão (obrigatório no Flutter Web —
  // no mobile o currentUser já está disponível, mas no web pode demorar
  // um tick enquanto o token é lido do localStorage).
  final user = await FirebaseAuth.instance
      .authStateChanges()
      .first
      .timeout(
        const Duration(seconds: 5),
        onTimeout: () => null, // sem sessão → tela de login
      );

  // Determina a rota inicial baseada no perfil real do usuário
  String rotaInicial = '/login';
  if (user != null) {
    rotaInicial = await NavigationService.definirRotaInicialUsuario(user);
  }

  runApp(MyApp(rotaInicial: rotaInicial));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.rotaInicial});

  final String rotaInicial;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    LocalStorageService.instancia.iniciarSincronizacaoAutomatica();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academia AndSport',
      debugShowCheckedModeBanner: false,

      // Troca automática de tema claro/escuro conforme o sistema
      theme: AppTheme.temaClaro,
      darkTheme: AppTheme.temaEscuro,
      themeMode: ThemeMode.system,

      initialRoute: widget.rotaInicial,

      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/gerador_ia': (context) => const GeradorTreinoIAPage(),
      },
    );
  }
}
