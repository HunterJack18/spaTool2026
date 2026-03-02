import 'package:flutter/material.dart';

//InputFiel Basico para ingresar texto

class inputField_Text extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final bool enable;
  final String label;
  bool obscure = false;
  inputField_Text({
    super.key,
    required this.controller,
    required this.icon,
    required this.enable,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF0077C8)),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF0077C8), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      enabled: enable,
    );
  }
}

//InputFiel para seleccionar una fecha
class inputFiel_date extends StatefulWidget {
  final TextEditingController controller;
  final IconData icon;
  final bool enable;
  final String label;
  bool obscure = false;
  final BuildContext context;
  inputFiel_date({
    super.key,
    required this.controller,
    required this.icon,
    required this.enable,
    required this.label,
    required this.context,
  });

  @override
  State<inputFiel_date> createState() => _inputFiel_dateState();
}

class _inputFiel_dateState extends State<inputFiel_date> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.obscure,
      enabled: widget.enable,
      readOnly: true, // Hace que no se pueda escribir manualmente
      onTap: () async {
        if (widget.enable) {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: const Color(
                      0xFF0077C8,
                    ), // Color primario del botón
                    onPrimary: Colors.white,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (pickedDate != null) {
            // Formatear la fecha (puedes cambiar el formato según necesites)
            String formattedDate =
                "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
            widget.controller.text = formattedDate;
          }
        }
      },
      decoration: InputDecoration(
        prefixIcon: Icon(widget.icon, color: const Color(0xFF0077C8)),
        labelText: widget.label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF0077C8), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon: Icon(
          Icons.calendar_today,
          color: const Color(0xFF0077C8),
        ), // Icono adicional
      ),
    );
    ;
  }
}
