import 'package:flutter/material.dart';
import 'package:farmatodo/config/themes/themes.dart';
import 'package:farmatodo/widget/IU/inputFiel.dart';
import 'package:farmatodo/widget/IU/notification.dart';
import 'package:farmatodo/models/medicamento.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

//########################################################################################

//Variables globales

//########################################################################################
List<Map<String, dynamic>> items = [];
List<Map<String, dynamic>> itemsFiltrados = [];

//########################################################################################

//Barra de busqueda

//########################################################################################
class BuildSearchBar extends StatefulWidget {
  final TextEditingController searchController;

  final bool showClearButton;

  const BuildSearchBar({
    super.key,
    required this.searchController,
    required this.showClearButton,
  });

  @override
  State<BuildSearchBar> createState() => _BuildSearchBarState();
}

class _BuildSearchBarState extends State<BuildSearchBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: ColorTheme[6],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorTheme[1].withOpacity(0.12)),
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
          Icon(Icons.search_rounded, color: ColorTheme[1].withOpacity(0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, lote, SKU o código...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: ColorTheme[1].withOpacity(0.6)),
              ),
            ),
          ),
          if (widget.showClearButton)
            IconButton(
              onPressed: () {
                widget.searchController.clear();
                FocusScope.of(context).unfocus();
              },
              icon: Icon(
                Icons.close_rounded,
                color: ColorTheme[1].withOpacity(0.85),
              ),
              tooltip: 'Limpiar',
            ),
        ],
      ),
    );
  }
}

//########################################################################################

//Filtros y orden de busqueda

//########################################################################################

class chipFiltro extends StatelessWidget {
  final String texto;
  final String valor;
  final String filtroActual;
  final Function(String) onSelecionado;
  final Color? color;
  const chipFiltro({
    super.key,
    required this.texto,
    required this.valor,
    required this.filtroActual,
    required this.onSelecionado,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activo = filtroActual == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: activo,
        selectedColor: (color ?? ColorTheme[0]).withOpacity(0.15),
        labelStyle: TextStyle(
          color: activo ? (color ?? ColorTheme[0]) : ColorTheme[1],
          fontWeight: FontWeight.w900,
        ),
        onSelected: (_) => onSelecionado(valor),
      ),
    );
  }
}

class buildFiltrosYOrden extends StatefulWidget {
  final String filtroActual;
  final String ordenActual;
  final Function(String) onFiltroCambiado;
  final Function(String) onOrdenCambiado;
  const buildFiltrosYOrden({
    super.key,
    required this.filtroActual,
    required this.ordenActual,
    required this.onFiltroCambiado,
    required this.onOrdenCambiado,
  });

  @override
  State<buildFiltrosYOrden> createState() => _buildFiltrosYOrdenState();
}

class _buildFiltrosYOrdenState extends State<buildFiltrosYOrden> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chipFiltro(
                    texto: 'Todos',
                    valor: 'todos',
                    filtroActual: widget.filtroActual,
                    onSelecionado: widget.onFiltroCambiado,
                  ),
                  chipFiltro(
                    texto: 'OK',
                    valor: 'ok',
                    color: ColorTheme[2],
                    filtroActual: widget.filtroActual,
                    onSelecionado: widget.onFiltroCambiado,
                  ),
                  chipFiltro(
                    texto: 'Cerca',
                    valor: 'cerca',
                    color: ColorTheme[4],
                    filtroActual: widget.filtroActual,
                    onSelecionado: widget.onFiltroCambiado,
                  ),
                  chipFiltro(
                    texto: 'Vencidos',
                    valor: 'vencidos',
                    color: ColorTheme[4],
                    filtroActual: widget.filtroActual,
                    onSelecionado: widget.onFiltroCambiado,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: ColorTheme[6],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorTheme[1].withOpacity(0.12)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: widget.ordenActual,
                icon: Icon(Icons.sort_rounded, color: ColorTheme[1]),
                style: TextStyle(
                  color: ColorTheme[1],
                  fontWeight: FontWeight.w800,
                ),
                onChanged: (v) => widget.onOrdenCambiado(v ?? 'fecha_asc'),
                items: const [
                  DropdownMenuItem(value: 'fecha_asc', child: Text('Fecha ↑')),
                  DropdownMenuItem(value: 'fecha_desc', child: Text('Fecha ↓')),
                  DropdownMenuItem(
                    value: 'nombre_asc',
                    child: Text('Nombre A-Z'),
                  ),
                  DropdownMenuItem(
                    value: 'vencidos_primero',
                    child: Text('Vencidos primero'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//#########################################################################################

//Formulario de nuevo seguimiento

//#########################################################################################

class FormNuevoSeg extends StatefulWidget {
  final TextEditingController skuController;
  final TextEditingController descripcionController;
  final TextEditingController nombreController;
  final TextEditingController codigoBarrasController;

  final TextEditingController fechaVec;
  final TextEditingController fechaRetiro;

  const FormNuevoSeg({
    super.key,
    required this.skuController,
    required this.descripcionController,
    required this.codigoBarrasController,
    required this.nombreController,
    required this.fechaVec,
    required this.fechaRetiro,
  });

  @override
  State<FormNuevoSeg> createState() => _FormNuevoSegState();
}

class _FormNuevoSegState extends State<FormNuevoSeg> {
  void actualizarFechaRetiro(DateTime fecha) {
    DateTime fechaRetiro = calcularFechaRetiro(fecha);

    String fechaRetiroFormateada =
        "${fechaRetiro.day.toString().padLeft(2, '0')}/"
        "${fechaRetiro.month.toString().padLeft(2, '0')}/"
        "${fechaRetiro.year}";

    widget.fechaRetiro.text = fechaRetiroFormateada;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          inputField_Text(
            controller: widget.skuController,
            enable: false,
            label: "SKU",
          ),
          const SizedBox(height: 14),
          inputField_Text(
            controller: widget.descripcionController,
            enable: false,
            label: "Descripción",
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: inputField_Text(
                  controller: widget.nombreController,
                  enable: false,
                  label: "Nombre",
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: inputField_Text(
                  controller: widget.codigoBarrasController,
                  enable: false,
                  label: "Codigo de barra",
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          inputFiel_date(
            controller: widget.fechaVec,
            icon: Icons.date_range,
            enable: true,
            label: "Fecha de vencimiento",
            context: context,
            onDateSelected: actualizarFechaRetiro,
          ),
          const SizedBox(height: 14),
          inputField_Text(
            controller: widget.fechaRetiro,
            enable: false,
            label: "Fecha de retiro (3 meses antes)",
          ),
        ],
      ),
    );
  }
}

DateTime calcularFechaRetiro(DateTime fechavencimiento) {
  return DateTime(
    fechavencimiento.year,
    fechavencimiento.month - 3,
    fechavencimiento.day,
  );
}

//#########################################################################################

//Ventana modal para el formulario del nuevo seguimiento

//#########################################################################################

Future<bool> MostrarModal(context, {ItemMedicamento? editar}) async {
  //controller del formulario
  final skuController = TextEditingController();
  final descripcionController = TextEditingController();
  final nombreController = TextEditingController();
  final codigoBarrasController = TextEditingController();
  final id_item = TextEditingController();

  //Fecha de retiro
  final fechaVencController = TextEditingController();
  final fechaRetiroController = TextEditingController();

  //controller para la barra de busqueda
  final barraBusquedaItem = TextEditingController();
  final String searchtext = "";

  //para menejar los resultados
  ValueNotifier<bool> isSearching = ValueNotifier(false);
  ValueNotifier<String> searchMessage = ValueNotifier('');

  // Variable para almacenar timeout del debounce
  Timer? _debounceTimer;

  //configurar el listener

  barraBusquedaItem.addListener(() {
    final query = barraBusquedaItem.text.trim();

    // Cancelar timer anterior (debounce)
    _debounceTimer?.cancel();

    // No buscar si el texto es muy corto
    if (query.length < 2) {
      searchMessage.value = 'Ingresa al menos 2 caracteres';
      return;
    }

    // Crear nuevo timer con debounce de 500ms
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      isSearching.value = true;
      searchMessage.value = 'Buscando...';

      try {
        // Buscar en Supabase
        final resultados = await _buscarEnSupabase(query);

        if (resultados.isEmpty) {
          searchMessage.value = 'No se encontraron resultados';
          // Limpiar campos si no hay resultados
          _limpiarCampos([
            skuController,
            descripcionController,
            nombreController,
            codigoBarrasController,
          ]);
        } else {
          // Tomar el primer resultado
          final item = resultados.first;

          // Llenar los controllers con los datos encontrados
          _llenarControllersDesdeItem(
            item,
            id_item,
            skuController,
            descripcionController,
            nombreController,
            codigoBarrasController,
          );

          searchMessage.value = '✓ Item encontrado';
        }
      } catch (e) {
        searchMessage.value = 'Error en la búsqueda: $e';
      } finally {
        isSearching.value = false;
      }
    });
  });

  final bool? resultado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        //escucha los cambios
        isSearching.addListener(() => setModalState(() {}));
        searchMessage.addListener(() => setModalState(() {}));
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: ColorTheme[6],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ColorTheme[0].withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        editar == null ? Icons.add_rounded : Icons.edit_rounded,
                        color: ColorTheme[0],
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      editar == null
                          ? 'Nuevo Seguimiento'
                          : 'Editar Medicamento',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: Icon(Icons.close_rounded, color: ColorTheme[1]),
                    ),
                  ],
                ),

                // Barra de búsqueda
                BuildSearchBar(
                  searchController: barraBusquedaItem,
                  showClearButton: barraBusquedaItem.text.isNotEmpty,
                ),

                // Mensaje de búsqueda/estado
                if (searchMessage.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        if (isSearching.value)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ColorTheme[0],
                              ),
                            ),
                          )
                        else if (searchMessage.value.startsWith('✓'))
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          )
                        else if (searchMessage.value.startsWith('Error'))
                          Icon(Icons.error, color: Colors.red, size: 16),

                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            searchMessage.value,
                            style: TextStyle(
                              color: searchMessage.value.startsWith('✓')
                                  ? Colors.green
                                  : searchMessage.value.startsWith('Error')
                                  ? Colors.red
                                  : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // Formulario
                Expanded(
                  child: SingleChildScrollView(
                    child: FormNuevoSeg(
                      skuController: skuController,
                      descripcionController: descripcionController,
                      nombreController: nombreController,
                      codigoBarrasController: codigoBarrasController,
                      fechaVec: fechaVencController,
                      fechaRetiro: fechaRetiroController,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: ColorTheme[1],
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await nuevoseguimiento(
                            id_item,
                            fechaVencController,
                            fechaRetiroController,
                          );
                          _limpiarCampos([
                            skuController,
                            descripcionController,
                            nombreController,
                            codigoBarrasController,
                            id_item,
                            fechaVencController,
                            fechaRetiroController,
                          ]);
                          Navigator.of(context).pop(true);
                          
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorTheme[0],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Guardar',
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
        );
      },
    ),
  );
  return resultado ?? false;
}

//#########################################################################################

// Función para formatear la fecha de manera correcta para su guardado en la bd

//#########################################################################################

String formatearFechaParaDB(String fechaStr) {
  if (fechaStr.isEmpty) return '';
  try {
    final parts = fechaStr.split('/');
    if (parts.length == 3) {
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return '$year-$month-$day'; // ✅ Formato correcto para Supabase
    }
  } catch (e) {
    print('Error formateando fecha: $e');
  }
  return fechaStr;
}

//#########################################################################################

// Función para Guardar la informacion del formulario en la tabla Proximos_itemsVecer

//#########################################################################################

Future<void> nuevoseguimiento(
  TextEditingController idItem,
  TextEditingController fechaVencController,
  TextEditingController fechaRetiroController,
) async {
  final supabase = Supabase.instance.client;

  try {
    await supabase.from("Proximos_itemVencer").insert({
      'id_item': idItem.text,
      'fech_venc': formatearFechaParaDB(fechaVencController.text),
      'fech_retiro': formatearFechaParaDB(fechaRetiroController.text),
      'status': 'en seguimiento',
    });
  } catch (e) {
    print("errror $e");
  }
}

//#########################################################################################

// Función para buscar un item en la talba item

//#########################################################################################

Future<List<Map<String, dynamic>>> _buscarEnSupabase(String query) async {
  final supabase = Supabase.instance.client;

  try {
    // Intentar convertir query a número para búsqueda exacta en campos numéricos
    int? numeroQuery = int.tryParse(query);

    // Construir filtros dinámicamente
    List<String> filtros = [
      'item_nomb.ilike.%$query%', // Búsqueda texto en nombre
    ];

    if (numeroQuery != null) {
      filtros.add('sku_item.eq.$numeroQuery');
      filtros.add('codbar_item.eq.$numeroQuery');
    }

    final response = await supabase
        .from('items')
        .select()
        .or(filtros.join(','))
        .limit(5);

    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    print('Error en búsqueda Supabase: $e');
    return [];
  }
}

// Función para llenar los controllers con los datos del item
void _llenarControllersDesdeItem(
  Map<String, dynamic> item,
  TextEditingController id_item,
  TextEditingController skuController,
  TextEditingController descripcionController,
  TextEditingController nombreController,
  TextEditingController codigoBarrasController,
) {
  id_item.text = item['id_item']?.toString() ?? '';
  skuController.text = item['sku_item']?.toString() ?? '';
  descripcionController.text = item['descript_item']?.toString() ?? '';
  nombreController.text = item['item_nomb']?.toString() ?? '';
  codigoBarrasController.text = item['codbar_item']?.toString() ?? '';
}

// Función para limpiar campos
void _limpiarCampos(List<TextEditingController> controllers) {
  for (var controller in controllers) {
    controller.clear();
  }
}

DateTime? _controllerToDateTime(TextEditingController controller) {
  try {
    // El texto viene en formato "dd/MM/yyyy" (ej: 25/03/2024)
    final parts = controller.text.split('/');
    if (parts.length == 3) {
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    }
  } catch (e) {
    print('Error parseando fecha: $e');
  }
  return null;
}
