import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int DAILY_REMINDER_ID = 9999;
  static const String NOTIFICATION_PREFIX = 'med_';

  Future<void> initialize() async {
    // Inicializar zona horaria
    tz_data.initializeTimeZones();
    
    // Configuración Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración iOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // Inicializar con callback
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        print('🔔 Notificación pulsada: ${details.payload}');
      },
    );
    
    // Crear canales para Android
    await _createNotificationChannels();
    
    // Solicitar permiso para Android 13+
    await _requestAndroidPermissions();
    
    print('✅ NotificationService inicializado correctamente');
  }
  
  Future<void> _createNotificationChannels() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'medication_retirement_channel',
        'Recordatorios de Retiro',
        description: 'Notificaciones sobre fechas de retiro de medicamentos',
        importance: Importance.high,
        playSound: true,
      );
      
      await _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
      
      print('✅ Canal de notificaciones creado');
    }
  }
  
  Future<void> _requestAndroidPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      print('✅ Permiso de notificaciones solicitado');
    }
  }

  // ✅ MÉTODO DE PRUEBA - Notificación inmediata
  Future<void> showTestNotification() async {
    print('🔔 Intentando mostrar notificación de prueba...');
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_retirement_channel',
      'Recordatorios de Retiro',
      channelDescription: 'Recordatorios para retirar medicamentos',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      999999,
      '🔔 Notificación de Prueba',
      'Si ves esto, el plugin funciona correctamente',
      details,
    );
    
    print('✅ Notificación de prueba enviada');
  }

  // ✅ Verificar si las notificaciones están habilitadas
  Future<bool> areNotificationsEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return result ?? false;
    }
    return true;
  }

  // ✅ Pedir permiso manualmente
  Future<void> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  // Programar notificación para una fecha específica
  Future<bool> scheduleNotification({
    required String idSeguimiento,
    required String medicationName,
    required DateTime scheduledDate,
    required int daysBefore,
    String? additionalInfo,
  }) async {
    try {
      final notificationId = '${NOTIFICATION_PREFIX}$idSeguimiento${daysBefore}d'.hashCode.abs();
      
      // Forzar hora a las 00:00 AM
      final dateAtMidnight = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        8, 0, 0,
      );
      
      final tz.TZDateTime tzDate = tz.TZDateTime.from(dateAtMidnight, tz.local);
      
      if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
        print('⏰ Fecha ya pasada, no se programa');
        return false;
      }
      
      String title;
      String body;
      
      switch (daysBefore) {
        case 7:
          title = '⚠️ Recordatorio de Retiro';
          body = '$medicationName debe retirarse en una semana';
          break;
        case 3:
          title = '🔔 Recordatorio Importante';
          body = '$medicationName debe retirarse en 3 días';
          break;
        case 1:
          title = '⚠️ ¡Último Recordatorio!';
          body = '$medicationName debe retirarse MAÑANA';
          break;
        default:
          title = '📅 Recordatorio de Retiro';
          body = '$medicationName debe retirarse en $daysBefore días';
      }
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medication_retirement_channel',
        'Recordatorios de Retiro',
        importance: Importance.high,
        priority: Priority.high,
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        tzDate,
        details,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '/seguimiento/$idSeguimiento',
      );
      
      print('✅ Notificación programada: $medicationName - ${daysBefore} días antes');
      return true;
    } catch (e) {
      print('❌ Error programando notificación: $e');
      return false;
    }
  }
  
  // Programar múltiples alertas
  Future<void> scheduleMultipleAlerts({
    required String idSeguimiento,
    required String medicationName,
    required DateTime fechaRetiro,
    required List<int> daysBeforeList,
  }) async {
    for (int days in daysBeforeList) {
      final alertDate = fechaRetiro.subtract(Duration(days: days));
      await scheduleNotification(
        idSeguimiento: idSeguimiento,
        medicationName: medicationName,
        scheduledDate: alertDate,
        daysBefore: days,
      );
    }
  }
  
  // Cancelar notificaciones de un seguimiento
  Future<void> cancelNotificationsForSeguimiento(String idSeguimiento) async {
    final daysList = [7, 3, 1];
    for (int days in daysList) {
      final notificationId = '${NOTIFICATION_PREFIX}$idSeguimiento${days}d'.hashCode.abs();
      await _notifications.cancel(notificationId);
    }
    print('🗑️ Notificaciones canceladas para: $idSeguimiento');
  }
  
  // Cancelar todas
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}