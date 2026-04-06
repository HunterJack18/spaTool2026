import 'package:farmatodo/services/notification_services.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farmatodo/models/medicamento.dart';

class MedicationNotificationScheduler {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notifications = NotificationService();

  // Días de anticipación para las notificaciones
  static const List<int> NOTIFICATION_DAYS = [7, 3, 1];

  // Verificar si se necesita reprogramar (una vez al día)
  Future<bool> shouldRescheduleToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReschedule = prefs.getString('last_notification_reschedule');
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (lastReschedule == today) {
      return false;
    }

    await prefs.setString('last_notification_reschedule', today);
    return true;
  }

  // Programar todas las notificaciones para un usuario
  Future<void> scheduleAllNotifications(String userId) async {
    print('🔄 Iniciando programación de notificaciones...');

    try {
      // Obtener todos los seguimientos activos con sus items
      final response = await _supabase
          .from('Proximos_itemVencer')
          .select('''
            *,
            items (*)
          ''')
          .eq('status', 'en seguimiento');

      int programadas = 0;

      for (var row in response) {
        final idSeguimiento = row['id_seguimiento'].toString();
        final fechaRetiro = DateTime.parse(row['fech_retiro']);
        final itemData = row['items'] as Map<String, dynamic>;
        final nombreMedicamento =
            itemData['item_nomb']?.toString() ?? 'Medicamento';

        // Debug: mostrar fechas calculadas
        print('📅 Medicamento: $nombreMedicamento');
        print('   Fecha de retiro: $fechaRetiro');

        for (int days in NOTIFICATION_DAYS) {
          final alertDate = fechaRetiro.subtract(Duration(days: days));
          print('   - Alerta de $days días: $alertDate');
        }

        // Cancelar notificaciones existentes
        await _notifications.cancelNotificationsForSeguimiento(idSeguimiento);

        // Programar nuevas notificaciones
        await _notifications.scheduleMultipleAlerts(
          idSeguimiento: idSeguimiento,
          medicationName: nombreMedicamento,
          fechaRetiro: fechaRetiro,
          daysBeforeList: NOTIFICATION_DAYS,
        );
        programadas++;
      }

      print('✅ Notificaciones programadas: $programadas seguimientos');
    } catch (e) {
      print('❌ Error programando notificaciones: $e');
    }
  }

  // Reprogramar cuando se agrega o actualiza un seguimiento
  Future<void> rescheduleForSeguimiento(String idSeguimiento) async {
    try {
      final response = await _supabase
          .from('Proximos_itemVencer')
          .select('''
            *,
            items (*)
          ''')
          .eq('id_seguimiento', idSeguimiento)
          .single();

      if (response != null) {
        final fechaRetiro = DateTime.parse(response['fech_retiro']);
        final itemData = response['items'] as Map<String, dynamic>;
        final nombreMedicamento =
            itemData['item_nomb']?.toString() ?? 'Medicamento';

        await _notifications.cancelNotificationsForSeguimiento(idSeguimiento);
        await _notifications.scheduleMultipleAlerts(
          idSeguimiento: idSeguimiento,
          medicationName: nombreMedicamento,
          fechaRetiro: fechaRetiro,
          daysBeforeList: NOTIFICATION_DAYS,
        );

        print(
            '🔄 Notificaciones reprogramadas para seguimiento: $idSeguimiento');
      }
    } catch (e) {
      print('❌ Error reprogramando notificaciones: $e');
    }
  }

  // Eliminar notificaciones cuando se elimina un seguimiento
  Future<void> removeNotificationsForSeguimiento(String idSeguimiento) async {
    await _notifications.cancelNotificationsForSeguimiento(idSeguimiento);
    print('🗑️ Notificaciones eliminadas para seguimiento: $idSeguimiento');
  }
}