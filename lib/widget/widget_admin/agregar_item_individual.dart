import 'package:flutter/material.dart';


Widget _inputField(
  TextEditingController controller,
  IconData icon,
  bool enable,
  String label, {
  bool obscure = false,
}) {
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

//editar el inventario elegido
Future<void> cargar_item_individual(
  Map<String, dynamic> invent,
  context,
) async {
  final id_invent = TextEditingController(text: invent['id_invent'].toString());
  final  nomb_item = TextEditingController();
  final  descrip_item = TextEditingController();
  final  sku_item = TextEditingController();
  final  cod_barr = TextEditingController();
  final  fech_venc = TextEditingController();


  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          "Agregar Producto",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0077C8),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _inputField(
                nomb_item,
                Icons.person_outline,
                true,
                "Nombre del Producto",
              ),
              const SizedBox(height: 15),
              _inputField(
                descrip_item,
                Icons.person_outline, 
                true, 
                "Descripción"
              ),
              const SizedBox(height: 15),
              _inputField(
                sku_item, 
                Icons.person_outline, 
                true, 
                "SKU "
                ),
              const SizedBox(height: 15),
              _inputField(
                cod_barr,
                Icons.person_outline,
                true,
                "Código de barra ",
              ),
              const SizedBox(height: 15),
              _inputField(
                fech_venc,
                Icons.person_outline,
                true,
                "Fecha de vencimiento",
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0077C8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
            },
            child: const Text("Guardar cambios"),
          ),
        ],
      );
    },
  );
}
