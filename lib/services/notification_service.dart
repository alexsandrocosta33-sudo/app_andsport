import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Handler para mensagens FCM recebidas com o app em background/encerrado.
/// Precisa ser função top-level (não pode ser método de classe).
/// Ignorado no web — service workers cuidam disso lá.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background: ${message.notification?.title}');
}

/// Serviço de notificações push (FCM + local notifications).
/// Singleton — acesse via NotificationService.instancia
class NotificationService {
  NotificationService._();
  static final NotificationService instancia = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _canalTreino = AndroidNotificationChannel(
    'lembrete_treino',
    'Lembrete de Treino',
    description: 'Lembretes diários para manter a consistência nos treinos',
    importance: Importance.high,
    playSound: true,
  );

  /// Inicializa FCM e notificações locais. Chamar em main() antes de runApp().
  Future<void> inicializar() async {
    // flutter_local_notifications e Platform.isAndroid/iOS não existem no web.
    // FCM web requer configuração adicional de service worker (VAPID key) que
    // ainda não está ativa — ignora com segurança sem bloquear o app.
    if (kIsWeb) {
      debugPrint('[FCM] Web detectado: inicialização nativa ignorada.');
      return;
    }

    try {
      // Registra handler de background antes de qualquer outra coisa
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      await _solicitarPermissao();
      await _configurarNotificacoesLocais();

      // Configura apresentação de notificações iOS em foreground
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listener para mensagens recebidas com app aberto
      FirebaseMessaging.onMessage.listen(_exibirNotificacaoForeground);

      // Log do token para facilitar testes
      final token = await _messaging.getToken();
      debugPrint('[FCM] Token: $token');
    } catch (e) {
      // Não bloqueia a inicialização do app se FCM falhar
      debugPrint('[FCM] Erro na inicialização: $e');
    }
  }

  Future<void> _solicitarPermissao() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permissão: ${settings.authorizationStatus}');
  }

  Future<void> _configurarNotificacoesLocais() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Cria o canal de notificação no Android 8+
    // Chamado apenas em mobile (kIsWeb já retornou antes de chegar aqui)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canalTreino);
  }

  /// Exibe notificação local quando uma mensagem FCM chega com o app em foreground.
  Future<void> _exibirNotificacaoForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canalTreino.id,
          _canalTreino.name,
          channelDescription: _canalTreino.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Agenda um lembrete diário de treino (repete todo dia no mesmo horário).
  /// Ignorado no web — flutter_local_notifications não suporta web.
  Future<void> agendarLembreteTreinoDiario() async {
    if (kIsWeb) return;

    await _localNotifications.periodicallyShow(
      1001,
      'Hora do treino! 💪',
      'Mantenha a consistência — seu treino de hoje está esperando.',
      RepeatInterval.daily,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canalTreino.id,
          _canalTreino.name,
          channelDescription: _canalTreino.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('[Notificações] Lembrete diário agendado.');
  }

  /// Cancela o lembrete de treino diário.
  Future<void> cancelarLembreteDiario() async {
    if (kIsWeb) return;
    await _localNotifications.cancel(1001);
    debugPrint('[Notificações] Lembrete diário cancelado.');
  }

  /// Retorna o token FCM do dispositivo atual.
  Future<String?> obterToken() => _messaging.getToken();
}
