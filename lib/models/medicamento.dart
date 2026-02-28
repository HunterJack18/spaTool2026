class Medicamento {
  int? id;
  String nombre;
  String codigoBarras;
  String descripcion;
  String lote;
  String fechaVencimiento;
  double precio;

  Medicamento({
    this.id,
    required this.nombre,
    required this.codigoBarras,
    required this.descripcion,
    required this.lote,
    required this.fechaVencimiento,
    required this.precio,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo_barras': codigoBarras,
      'descripcion': descripcion,
      'lote': lote,
      'fecha_vencimiento': fechaVencimiento,
      'precio': precio,
    };
  }
}
