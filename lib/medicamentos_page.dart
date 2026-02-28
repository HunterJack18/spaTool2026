import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MedicamentosPage extends StatefulWidget {
  final int idInvent;

  const MedicamentosPage({
    Key? key,
    required this.idInvent,
  }) : super(key: key);

  @override
  State<MedicamentosPage> createState() => _MedicamentosPageState();
}

class _MedicamentosPageState extends State<MedicamentosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ItemMedicamento> _medicamentos = [];
  bool _cargando = true;

  // UI / filtros
  String _filtro = 'todos'; // todos | ok | cerca | vencidos
  final int diasCerca = 15; // 🔴 cerca de vencerse

  // Orden
  String _orden = 'fecha_asc'; // fecha_asc | fecha_desc | nombre_asc | vencidos_primero

  // Búsqueda
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  // Form
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _codigoBarrasController = TextEditingController();
  final _skuController = TextEditingController();
  final _loteController = TextEditingController();
  DateTime? _fechaVencimiento;

  // Colores
  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _secondaryColor = const Color(0xFF64748B);
  final Color _successColor = const Color(0xFF10B981);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _cargarMedicamentos();

    _searchController.addListener(() {
      final v = _searchController.text.trim();
      if (v != _searchText) setState(() => _searchText = v);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nombreController.dispose();
    _descripcionController.dispose();
    _codigoBarrasController.dispose();
    _skuController.dispose();
    _loteController.dispose();
    super.dispose();
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _dateToPgDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  int? _toNullableBigint(String input) {
    final v = input.trim();
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  int _diasParaVencer(DateTime fechaVenc) {
    final hoy = DateTime.now();
    final a = DateTime(hoy.year, hoy.month, hoy.day);
    final b = DateTime(fechaVenc.year, fechaVenc.month, fechaVenc.day);
    return b.difference(a).inDays;
  }

  Future<void> _cargarMedicamentos() async {
    try {
      setState(() => _cargando = true);

      final res = await _supabase
          .from('items')
          .select()
          .eq('id_invent', widget.idInvent)
          .order('fech_venc', ascending: true);

      setState(() {
        _medicamentos = (res as List)
            .map((e) => ItemMedicamento.fromMap(e as Map<String, dynamic>))
            .toList();
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      _mostrarSnackBar('Error cargando medicamentos: $e', _errorColor);
    }
  }

  List<ItemMedicamento> _aplicarFiltroBusquedaYOrden() {
    final q = _searchText.toLowerCase();

    bool matchBusqueda(ItemMedicamento m) {
      if (q.isEmpty) return true;

      final nombre = m.nombreMedicamento.toLowerCase();
      final desc = m.descripcion.toLowerCase();
      final sku = (m.skuItem?.toString() ?? '').toLowerCase();
      final cod = (m.codbarItem?.toString() ?? '').toLowerCase();
      final lote = (m.numLote ?? '').toLowerCase();

      return nombre.contains(q) ||
          desc.contains(q) ||
          sku.contains(q) ||
          cod.contains(q) ||
          lote.contains(q);
    }

    bool matchFiltro(ItemMedicamento m) {
      final dias = _diasParaVencer(m.fechaVencimiento);
      switch (_filtro) {
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

    final list = _medicamentos.where((m) => matchFiltro(m) && matchBusqueda(m)).toList();

    list.sort((a, b) {
      final da = _diasParaVencer(a.fechaVencimiento);
      final db = _diasParaVencer(b.fechaVencimiento);

      if (_orden == 'vencidos_primero') {
        // vencidos primero, luego cerca, luego ok; dentro de cada grupo por fecha asc
        int grupo(int d) {
          if (d < 0) return 0; // vencido
          if (d <= diasCerca) return 1; // cerca
          return 2; // ok
        }

        final ga = grupo(da);
        final gb = grupo(db);

        if (ga != gb) return ga.compareTo(gb);
        return a.fechaVencimiento.compareTo(b.fechaVencimiento);
      }

      if (_orden == 'nombre_asc') {
        return a.nombreMedicamento.toLowerCase().compareTo(b.nombreMedicamento.toLowerCase());
      }

      if (_orden == 'fecha_desc') {
        return b.fechaVencimiento.compareTo(a.fechaVencimiento);
      }

      // fecha_asc por defecto
      return a.fechaVencimiento.compareTo(b.fechaVencimiento);
    });

    return list;
  }

  Future<void> _seleccionarFecha() async {
    final DateTime hoy = DateTime.now();
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento ?? hoy.add(const Duration(days: 30)),
      firstDate: DateTime(hoy.year - 5),
      lastDate: DateTime(hoy.year + 20),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: _primaryColor, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );

    if (fechaSeleccionada != null) setState(() => _fechaVencimiento = fechaSeleccionada);
  }

  void _limpiarFormulario() {
    _nombreController.clear();
    _descripcionController.clear();
    _codigoBarrasController.clear();
    _skuController.clear();
    _loteController.clear();
    _fechaVencimiento = null;
  }

  void _cargarFormularioDesde(ItemMedicamento med) {
    _nombreController.text = med.nombreMedicamento;
    _descripcionController.text = med.descripcion;
    _codigoBarrasController.text = med.codbarItem?.toString() ?? '';
    _skuController.text = med.skuItem?.toString() ?? '';
    _loteController.text = med.numLote ?? '';
    _fechaVencimiento = med.fechaVencimiento;
  }

  Future<void> _guardarNuevo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaVencimiento == null) {
      _mostrarSnackBar('Selecciona fecha de vencimiento', _errorColor);
      return;
    }

    try {
      final payload = <String, dynamic>{
        'id_invent': widget.idInvent,
        'nombre_medicamento': _nombreController.text.trim(),
        'descript_item': _descripcionController.text.trim(),
        'codbar_item': _toNullableBigint(_codigoBarrasController.text),
        'sku_item': _toNullableBigint(_skuController.text),
        'num_lote': _loteController.text.trim(),
        'fech_venc': _dateToPgDate(_fechaVencimiento!),
      };

      await _supabase.from('items').insert(payload);
      await _cargarMedicamentos();

      if (mounted) Navigator.of(context).pop();
      _limpiarFormulario();
      _mostrarSnackBar('Agregado correctamente', _successColor);
    } catch (e) {
      _mostrarSnackBar('Error al guardar: $e', _errorColor);
    }
  }

  Future<void> _guardarEdicion(ItemMedicamento original) async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaVencimiento == null) {
      _mostrarSnackBar('Selecciona fecha de vencimiento', _errorColor);
      return;
    }

    try {
      final payload = <String, dynamic>{
        'nombre_medicamento': _nombreController.text.trim(),
        'descript_item': _descripcionController.text.trim(),
        'codbar_item': _toNullableBigint(_codigoBarrasController.text),
        'sku_item': _toNullableBigint(_skuController.text),
        'num_lote': _loteController.text.trim(),
        'fech_venc': _dateToPgDate(_fechaVencimiento!),
      };

      await _supabase.from('items').update(payload).eq('id_item', original.idItem);
      await _cargarMedicamentos();

      if (mounted) Navigator.of(context).pop();
      _limpiarFormulario();
      _mostrarSnackBar('Actualizado correctamente', _successColor);
    } catch (e) {
      _mostrarSnackBar('Error al actualizar: $e', _errorColor);
    }
  }

  Future<bool> _confirmarEliminarSwipe(ItemMedicamento med) async {
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
                decoration: BoxDecoration(color: _errorColor.withOpacity(0.10), shape: BoxShape.circle),
                child: Icon(Icons.delete_outline_rounded, color: _errorColor, size: 30),
              ),
              const SizedBox(height: 14),
              const Text('¿Eliminar medicamento?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                'Se eliminará "${med.nombreMedicamento}" permanentemente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondaryColor, height: 1.35),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        backgroundColor: _errorColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Eliminar',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
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
      await _supabase.from('items').delete().eq('id_item', med.idItem);

      setState(() {
        _medicamentos.removeWhere((x) => x.idItem == med.idItem);
      });

      _mostrarSnackBar('Eliminado', _warningColor);
      return true;
    } catch (e) {
      _mostrarSnackBar('Error al eliminar: $e', _errorColor);
      return false;
    }
  }

  String _formatearFecha(DateTime fecha) => '${fecha.day}/${fecha.month}/${fecha.year}';

  String _calcularDiasRestantes(DateTime fechaVencimiento) {
    final d = _diasParaVencer(fechaVencimiento);
    if (d < 0) return 'Vencido hace ${d.abs()} días';
    if (d == 0) return 'Vence hoy';
    if (d == 1) return 'Vence en 1 día';
    return 'Vence en $d días';
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _secondaryColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: _secondaryColor.withOpacity(0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, lote, SKU o código...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: _secondaryColor.withOpacity(0.6)),
              ),
            ),
          ),
          if (_searchText.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
              icon: Icon(Icons.close_rounded, color: _secondaryColor.withOpacity(0.85)),
              tooltip: 'Limpiar',
            ),
        ],
      ),
    );
  }

  Widget _chipFiltro(String texto, String valor, {Color? color}) {
    final activo = _filtro == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: activo,
        selectedColor: (color ?? _primaryColor).withOpacity(0.15),
        labelStyle: TextStyle(
          color: activo ? (color ?? _primaryColor) : _secondaryColor,
          fontWeight: FontWeight.w900,
        ),
        onSelected: (_) => setState(() => _filtro = valor),
      ),
    );
  }

  Widget _buildFiltrosYOrden() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipFiltro('Todos', 'todos'),
                  _chipFiltro('OK', 'ok', color: _successColor),
                  _chipFiltro('Cerca', 'cerca', color: _errorColor),
                  _chipFiltro('Vencidos', 'vencidos', color: _errorColor),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _secondaryColor.withOpacity(0.12)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _orden,
                icon: Icon(Icons.sort_rounded, color: _secondaryColor),
                style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.w800),
                onChanged: (v) => setState(() => _orden = v ?? 'fecha_asc'),
                items: const [
                  DropdownMenuItem(value: 'fecha_asc', child: Text('Fecha ↑')),
                  DropdownMenuItem(value: 'fecha_desc', child: Text('Fecha ↓')),
                  DropdownMenuItem(value: 'nombre_asc', child: Text('Nombre A-Z')),
                  DropdownMenuItem(value: 'vencidos_primero', child: Text('Vencidos primero')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _secondaryColor.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _secondaryColor)),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  void _mostrarFormulario({ItemMedicamento? editar}) {
    if (editar == null) {
      _limpiarFormulario();
    } else {
      _cargarFormularioDesde(editar);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(editar == null ? Icons.add_rounded : Icons.edit_rounded,
                        color: _primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    editar == null ? 'Nuevo Medicamento' : 'Editar Medicamento',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: _secondaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nombreController,
                          decoration: InputDecoration(
                            labelText: 'Nombre del medicamento *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: _primaryColor, width: 1.6),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _loteController,
                          decoration: InputDecoration(
                            labelText: 'Número de lote (num_lote)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: _primaryColor, width: 1.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descripcionController,
                          decoration: InputDecoration(
                            labelText: 'Descripción',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: _primaryColor, width: 1.6),
                            ),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _codigoBarrasController,
                                decoration: InputDecoration(
                                  labelText: 'Código de barras',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _skuController,
                                decoration: InputDecoration(
                                  labelText: 'SKU',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: _seleccionarFecha,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: _secondaryColor.withOpacity(0.25)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, color: _primaryColor, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Fecha de vencimiento *',
                                          style: TextStyle(fontSize: 12, color: _secondaryColor)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _fechaVencimiento != null
                                            ? _formatearFecha(_fechaVencimiento!)
                                            : 'Seleccionar fecha',
                                        style: TextStyle(
                                          color: _fechaVencimiento != null
                                              ? Colors.black
                                              : _secondaryColor.withOpacity(0.5),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down_rounded, color: _secondaryColor),
                              ],
                            ),
                          ),
                        ),
                        if (_fechaVencimiento != null) ...[
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final d = _diasParaVencer(_fechaVencimiento!);
                              final bool vencido = d < 0;
                              final bool cerca = d >= 0 && d <= diasCerca;
                              final Color c = (vencido || cerca) ? _errorColor : _successColor;

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: c.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: c.withOpacity(0.22)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      (vencido || cerca) ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                                      color: c,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _calcularDiasRestantes(_fechaVencimiento!),
                                        style: TextStyle(color: c, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancelar', style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: editar == null ? _guardarNuevo : () => _guardarEdicion(editar),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        editar == null ? 'Guardar' : 'Actualizar',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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
  }

  Widget _buildTarjetaMedicamento(ItemMedicamento med) {
    final dias = _diasParaVencer(med.fechaVencimiento);
    final vencido = dias < 0;
    final cerca = dias >= 0 && dias <= diasCerca;

    Color estadoColor = _successColor;
    IconData estadoIcon = Icons.check_circle_rounded;
    String estadoTexto = 'En buen estado';

    if (vencido) {
      estadoColor = _errorColor;
      estadoIcon = Icons.error_rounded;
      estadoTexto = 'VENCIDO';
    } else if (cerca) {
      estadoColor = _errorColor;
      estadoIcon = Icons.warning_rounded;
      estadoTexto = '¡CERCA DE VENCER!';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estadoColor.withOpacity(0.40), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.medication_rounded, color: estadoColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.nombreMedicamento,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(estadoIcon, color: estadoColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            estadoTexto,
                            style: TextStyle(color: estadoColor, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: estadoColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _calcularDiasRestantes(med.fechaVencimiento),
                          style: TextStyle(color: estadoColor, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'editar') _mostrarFormulario(editar: med);
                    if (v == 'eliminar') _confirmarEliminarSwipe(med);
                  },
                  icon: Icon(Icons.more_vert_rounded, color: _secondaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: _primaryColor),
                          const SizedBox(width: 8),
                          const Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: _errorColor),
                          const SizedBox(width: 8),
                          const Text('Eliminar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (med.numLote != null && med.numLote!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Lote: ${med.numLote}',
                style: TextStyle(color: _secondaryColor.withOpacity(0.9), fontWeight: FontWeight.w800),
              ),
            ],
            if (med.descripcion.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(med.descripcion, style: TextStyle(color: _secondaryColor.withOpacity(0.9), height: 1.35)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _miniInfo('Código', med.codbarItem?.toString() ?? '—')),
                const SizedBox(width: 12),
                Expanded(child: _miniInfo('SKU', med.skuItem?.toString() ?? '—')),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: estadoColor.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: estadoColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vence el ${_formatearFecha(med.fechaVencimiento)}',
                      style: TextStyle(fontWeight: FontWeight.w900, color: estadoColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedList(List<ItemMedicamento> lista) {
    // clave basada en filtro + búsqueda + orden + tamaño => anima cuando cambia
    final key = ValueKey('${_filtro}_${_orden}_${_searchText}_${lista.length}');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        final fade = FadeTransition(opacity: anim, child: child);
        final slide = SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
          child: fade,
        );
        return slide;
      },
      child: ListView.builder(
        key: key,
        padding: const EdgeInsets.all(16),
        itemCount: lista.length,
        itemBuilder: (context, i) {
          final med = lista[i];

          return Dismissible(
            key: ValueKey('dismiss_${med.idItem}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async => await _confirmarEliminarSwipe(med),
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _errorColor.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.delete_outline_rounded, color: _errorColor),
                  const SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: _errorColor, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            child: _buildTarjetaMedicamento(med),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _aplicarFiltroBusquedaYOrden();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Gestión de Medicamentos',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        backgroundColor: _surfaceColor,
        foregroundColor: _primaryColor,
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _primaryColor),
            onPressed: _cargarMedicamentos,
          ),
        ],
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)))
          : Column(
              children: [
                _buildSearchBar(),
                _buildFiltrosYOrden(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargarMedicamentos,
                    backgroundColor: _surfaceColor,
                    color: _primaryColor,
                    child: _buildAnimatedList(lista),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        
      ),
    );
  }
}

class ItemMedicamento {
  final String idItem;
  final String nombreMedicamento;
  final String descripcion;
  final int? codbarItem;
  final int? skuItem;
  final String? numLote; // ✅ nuevo
  final DateTime fechaVencimiento;

  ItemMedicamento({
    required this.idItem,
    required this.nombreMedicamento,
    required this.descripcion,
    required this.codbarItem,
    required this.skuItem,
    required this.numLote,
    required this.fechaVencimiento,
  });

  factory ItemMedicamento.fromMap(Map<String, dynamic> map) {
    return ItemMedicamento(
      idItem: map['id_item'].toString(),
      nombreMedicamento: (map['nombre_medicamento'] ?? '').toString(),
      descripcion: (map['descript_item'] ?? '').toString(),
      codbarItem: map['codbar_item'] == null ? null : int.tryParse(map['codbar_item'].toString()),
      skuItem: map['sku_item'] == null ? null : int.tryParse(map['sku_item'].toString()),
      numLote: map['num_lote']?.toString(),
      fechaVencimiento: DateTime.parse(map['fech_venc'].toString()),
    );
  }
}
