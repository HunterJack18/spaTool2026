import 'package:flutter/material.dart';
import 'package:farmatodo/config/themes/themes.dart';

class mostrarSnackBar {
  static void mostrar(
    BuildContext context, {
    required String mensaje,
    required Color colorFondo,
    Duration duracion = const Duration(seconds: 4),
    IconData? icono,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icono != null) ...[
              Icon(icono, color: Colors.white, size: 20),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                mensaje,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: colorFondo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: duracion,
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
  
  // Métodos predefinidos para colores comunes
  static void success(BuildContext context, String mensaje) {
    mostrar(context, mensaje: mensaje, colorFondo: ColorTheme[2]);
  }
  
  static void error(BuildContext context, String mensaje) {
    mostrar(context, mensaje: mensaje, colorFondo: ColorTheme[4]);
  }
  
  static void warning(BuildContext context, String mensaje) {
    mostrar(context, mensaje: mensaje, colorFondo: ColorTheme[3]);
  }
  
  static void info(BuildContext context, String mensaje) {
    mostrar(context, mensaje: mensaje, colorFondo: ColorTheme[1]);
  }
}
