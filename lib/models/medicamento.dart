class ItemMedicamento {
  final String idItem;
  final String item_nomb;
  final String descript_item;
  final int? codbar_item;
  final int? sku_item;

  ItemMedicamento({
    required this.idItem,
    required this.item_nomb,
    required this.descript_item,
    required this.codbar_item,
    required this.sku_item,
  });

  factory ItemMedicamento.fromMap(Map<String, dynamic> map) {
  
    return ItemMedicamento(
      idItem: map['id_item'].toString(),
      item_nomb: (map['item_nomb'] ?? '').toString(),
      descript_item: (map['descript_item'] ?? '').toString(),
      codbar_item: map['codbar_item'] == null
          ? null
          : int.tryParse(map['codbar_item'].toString()),
      sku_item: map['sku_item'] == null
          ? null
          : int.tryParse(map['sku_item'].toString()),
    );
  }
}

class ItemSeguimiento {
  final String idSeguimiento;
  final String idItem;
  final DateTime? fechaRetiro;  
  final DateTime? fechaVenc;     
  final String status;

  ItemSeguimiento({
    required this.idSeguimiento,
    required this.idItem,
    this.fechaRetiro,    
    this.fechaVenc,      
    required this.status,
  });

  factory ItemSeguimiento.fromMap(Map<String, dynamic> map) {
    DateTime? parseFecha(String key) {
      if (map[key] == null) return null;  // ✅ Devuelve null si no hay fecha
      try {
        return DateTime.parse(map[key].toString());
      } catch (e) {
        print('Error parseando fecha $key: $e');
        return null;  // ✅ Devuelve null si hay error
      }
    }

    return ItemSeguimiento(
      idSeguimiento: map['id_seguimiento']?.toString() ?? '',
      idItem: map['id_item']?.toString() ?? '',
      fechaRetiro: parseFecha('fech_retiro'),
      fechaVenc: parseFecha('fech_venc'),
      status: map['status']?.toString() ?? '',
    );
  }
}
