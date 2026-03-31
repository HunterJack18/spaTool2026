import 'package:farmatodo/widget/IU/notification.dart';
import 'package:flutter/material.dart';
import 'package:farmatodo/config/themes/themes.dart';
import 'package:farmatodo/widget/widget_admin/ItemProximos.dart';
import 'package:farmatodo/widget/IU/tarjetasSeguimientos.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:farmatodo/models/medicamento.dart';

class MedicamentosPage2 extends StatefulWidget {
  const MedicamentosPage2({super.key});

  @override
  State<MedicamentosPage2> createState() => _MedicamentosPage2State();
}

class _MedicamentosPage2State extends State<MedicamentosPage2> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Datos de seguimientos
  List<ItemSeguimiento> _seguimientos = [];
  Map<String, ItemMedicamento> _itemsInfo = {};

  // UI / filtros
  String filtro = 'todos';
  final int diasCerca = 15;

  // Orden
  String orden = 'fecha_asc';

  bool _cargando = true;

  // Barra de búsqueda
  final TextEditingController searchController = TextEditingController();
  String searchText = '';

  @override
  void initState() {
    super.initState();
    _cargarSeguimientos();

    searchController.addListener(() {
      final v = searchController.text.trim();
      if (v != searchText) setState(() => searchText = v);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // Función para calcular días hasta vencimiento
  int _diasParaVencer(DateTime? fechaVenc) {
    if (fechaVenc == null) return 999999; // Valor grande para nulos
    final hoy = DateTime.now();
    final a = DateTime(hoy.year, hoy.month, hoy.day);
    final b = DateTime(fechaVenc.year, fechaVenc.month, fechaVenc.day);
    return b.difference(a).inDays;
  }

  // Función para aplicar filtros y búsqueda
  List<ItemSeguimiento> _aplicarFiltroBusquedaYOrden() {
    final q = searchText.toLowerCase();

    bool matchBusqueda(ItemSeguimiento s) {
      if (q.isEmpty) return true;

      final itemInfo = _itemsInfo[s.idItem];
      if (itemInfo == null) return false;

      final nombre = itemInfo.item_nomb.toLowerCase();
      final desc = itemInfo.descript_item.toLowerCase();
      final sku = (itemInfo.sku_item?.toString() ?? '').toLowerCase();
      final cod = (itemInfo.codbar_item?.toString() ?? '').toLowerCase();

      return nombre.contains(q) ||
          desc.contains(q) ||
          sku.contains(q) ||
          cod.contains(q);
    }

    bool matchFiltro(ItemSeguimiento s) {
      final dias = _diasParaVencer(s.fechaVenc);
      switch (filtro) {
        case 'vencidos':
          return dias < 0;
        case 'cerca':
          return dias >= 0 && dias <= diasCerca;
        case 'ok':
          return dias > diasCerca;
        default:
          return true;
      }
    }

    final list = _seguimientos
        .where((s) => matchFiltro(s) && matchBusqueda(s))
        .toList();

    list.sort((a, b) {
      final da = _diasParaVencer(a.fechaVenc);
      final db = _diasParaVencer(b.fechaVenc);

      if (orden == 'vencidos_primero') {
        int grupo(int d) {
          if (d < 0) return 0;
          if (d <= diasCerca) return 1;
          return 2;
        }

        final ga = grupo(da);
        final gb = grupo(db);
        if (ga != gb) return ga.compareTo(gb);

        // Usar los días calculados en lugar de fechas
        return da.compareTo(db);
      }

      if (orden == 'fecha_desc') {
        return db.compareTo(da); // Usar días calculados
      }

      // fecha_asc por defecto
      return da.compareTo(db); // Usar días calculados
    });

    return list;
  }

  // Cargar seguimientos desde Supabase
  Future<void> _cargarSeguimientos() async {
    try {
      setState(() => _cargando = true);
      final response = await _supabase.from('Proximos_itemVencer').select('''
          *,
          items (*)
        ''');

      // Listas para almacenar los datos
      final List<ItemSeguimiento> seguimientos = [];
      final Map<String, ItemMedicamento> itemsInfo = {};

      // Procesar cada resultado
      for (var row in response) {
        // 1. Extraer y procesar los datos del seguimiento
        final seguimiento = ItemSeguimiento.fromMap(row);
        seguimientos.add(seguimiento);
        print("${seguimiento.fechaVenc} ${seguimiento.fechaRetiro}");
        // 2. Extraer y procesar los datos del item relacionado
        final itemData = row['items'] as Map<String, dynamic>?;

        if (itemData != null) {
          final item = ItemMedicamento.fromMap(itemData);
          final itemId = item.idItem;

          // Solo guardar si no existe (evita duplicados)
          if (!itemsInfo.containsKey(itemId)) {
            itemsInfo[itemId] = item;
          }
        }
      }

      setState(() {
        _seguimientos = seguimientos;
        _itemsInfo = itemsInfo;
        _cargando = false;
      });
    } catch (e) {
      mostrarSnackBar.error(context, '❌ Error cargando seguimientos: $e');
      setState(() => _cargando = false);
    }
  }

  // Confirmar eliminación
  Future<bool> _confirmarEliminar(ItemSeguimiento seguimiento) async {
    bool confirmado = false;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: ColorTheme[4].withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: ColorTheme[4],
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '¿Eliminar seguimiento?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Se eliminará este seguimiento permanentemente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ColorTheme[1], height: 1.35),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        confirmado = true;
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorTheme[4],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!confirmado) return false;

    try {
      await _supabase
          .from('Proximos_itemVencer')
          .delete()
          .eq('id_seguimiento', seguimiento.idSeguimiento);

      setState(() {
        _seguimientos.removeWhere(
          (x) => x.idSeguimiento == seguimiento.idSeguimiento,
        );
      });

      mostrarSnackBar.success(context, 'Eliminado');
      return true;
    } catch (e) {
      mostrarSnackBar.error(context, 'Error al eliminar: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final listaFiltrada = _aplicarFiltroBusquedaYOrden();

    return Scaffold(
      backgroundColor: ColorTheme[5],
      appBar: AppBar(
        title: const Text(
          'Seguimiento de Próximos a Vencer',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        backgroundColor: ColorTheme[6],
        foregroundColor: ColorTheme[0],
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: ColorTheme[0]),
            onPressed: _cargarSeguimientos,
          ),
        ],
      ),
      body: _cargando
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ColorTheme[0]),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  BuildSearchBar(
                    searchController: searchController,
                    showClearButton: searchText.isNotEmpty,
                  ),
                  buildFiltrosYOrden(
                    filtroActual: filtro,
                    ordenActual: orden,
                    onFiltroCambiado: (nuevoFiltro) {
                      setState(() {
                        filtro = nuevoFiltro;
                      });
                    },
                    onOrdenCambiado: (nuevoOrden) {
                      setState(() {
                        orden = nuevoOrden;
                      });
                    },
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _cargarSeguimientos,
                      backgroundColor: ColorTheme[6],
                      color: ColorTheme[0],
                      child: ListaSeguimientos(
                        seguimientos: listaFiltrada,
                        itemsInfo: _itemsInfo,
                        diasCerca: diasCerca,
                        onEliminar: _confirmarEliminar,
                        onEditar: (seguimiento) {
                          // Aquí puedes abrir el modal para editar
                          // MostrarModal(context, editar: seguimiento);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => MostrarModal(context),
        backgroundColor: ColorTheme[0],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
