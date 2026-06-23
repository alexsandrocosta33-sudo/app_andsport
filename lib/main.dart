import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/gerador_treino_ia_page.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'services/local_storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializa cache offline e notificações antes do app subir
  await LocalStorageService.inicializar();
  await NotificationService.instancia.inicializar();

  // Verifica se o usuário já passou pelo onboarding
  final prefs = await SharedPreferences.getInstance();
  final onboardingConcluido = prefs.getBool('onboarding_concluido') ?? false;

  runApp(MyApp(onboardingConcluido: onboardingConcluido));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.onboardingConcluido});

  final bool onboardingConcluido;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Inicia sincronização automática quando a conexão for restaurada
    LocalStorageService.instancia.iniciarSincronizacaoAutomatica();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academia AndSport',
      debugShowCheckedModeBanner: false,

      // Temas com suporte automático ao modo escuro do sistema
      theme: AppTheme.temaClaro,
      darkTheme: AppTheme.temaEscuro,
      themeMode: ThemeMode.system,

      // Redireciona para onboarding na primeira abertura
      initialRoute: widget.onboardingConcluido ? '/login' : '/onboarding',

      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/gerador_ia': (context) => const GeradorTreinoIAPage(),
      },
    );
  }
}
