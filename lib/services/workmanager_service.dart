// lib/services/workmanager_service.dart
import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'medication_notification_scheduler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 Ejecutando tarea: $task');
    
    try {
      // Inicializar Supabase para background
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']??'', 
        anonKey: dotenv.env['SUPABASE_ANNON_KEY']??''
      );
      
      final userId = inputData?['userId'] as String?;
      
      if (userId == null) {
        print('❌ No se encontró userId');
        return Future.value(false);
      }
      
      final scheduler = MedicationNotificationScheduler();
      
      switch (task) {
        case 'scheduleNotifications':
          await scheduler.scheduleAllNotifications(userId);
          break;
        case 'dailyCheck':
          // Solo reprogramar si es necesario
          if (await scheduler.shouldRescheduleToday()) {
            await scheduler.scheduleAllNotifications(userId);
          }
          break;
        default:
          print('⚠️ Tarea desconocida: $task');
      }
      
      return Future.value(true);
    } catch (e) {
      print('❌ Error en tarea $task: $e');
      return Future.value(false);
    }
  });
}

class WorkManagerService {
  static const String scheduleNotificationsTask = 'scheduleNotifications';
  static const String dailyCheckTask = 'dailyCheck';
  
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
  }
  
  static Future<void> registerPeriodicTasks(String userId) async {
    // Tarea diaria para reprogramar notificaciones
    await Workmanager().registerPeriodicTask(
      'dailyNotificationReschedule',
      dailyCheckTask,
      frequency: Duration(hours: 24),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      inputData: {'userId': userId},
    );
  }
  
  static Future<void> scheduleImmediateCheck(String userId) async {
    await Workmanager().registerOneOffTask(
      'immediateCheck',
      scheduleNotificationsTask,
      initialDelay: Duration(seconds: 5),
      inputData: {'userId': userId},
    );
  }
  
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
    print('🗑️ Todas las tareas canceladas');
  }
}