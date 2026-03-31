import 'package:farmatodo/widget/IU/inputFiel.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgregarItem extends StatefulWidget {
  final int id_invent;
  final String nomb_invent;
  const AgregarItem({
    Key? key,
    required this.id_invent,
    required this.nomb_invent,
  }) : super(key: key);

  @override
  State<AgregarItem> createState() => _AgregarItem();
}

class _AgregarItem extends State<AgregarItem> {
  //intanciacion de supabase
  final SupabaseClient supabase = Supabase.instance.client;

  //variables locales
  final nomb_item = TextEditingController();
  final descript_item = TextEditingController();
  final sku_item = TextEditingController();
  final codbar_item = TextEditingController();
  //final fech_venc = TextEditingController();

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> itemsFiltrados = [];

  @override
  void initState() {
    super.initState();
    cargaritems();
    _searchController.addListener(_filtrarItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void mostrarMensaje(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }


void _filtrarItems() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        itemsFiltrados = List.from(items);
      } else {
        itemsFiltrados = items.where((item) {
          final nombre = item['item_nomb'].toString().toLowerCase();
          final cod_user = item['codbar_item'].toString().toLowerCase();
          final rol = item['sku_item'].toString().toLowerCase();
          return nombre.contains(query) || cod_user.contains(query) || rol.contains(query);
        }).toList();
      }
    });
  }
  //cargara una lista de los inventarios actuales
  Future<void> cargaritems() async {
    final data = await supabase
        .from('items')
        .select('*')
        .eq("id_invent", widget.id_invent);
    setState(() {
      items = data;
      itemsFiltrados = List.from(items);
    });
  }

  //agregar un item nuevo a la iventario actual
  Future<void> addItem() async {
    if (nomb_item.text.isEmpty ||
        descript_item.text.isEmpty ||
        sku_item.text.isEmpty ||
        codbar_item.text.isEmpty) {
      mostrarMensaje("❌ debellenar todos los campos");
      return;
    }
    try {
      await supabase.from("items").insert({
        "id_invent": widget.id_invent,
        "item_nomb":nomb_item.text,
        "descript_item": descript_item.text,
        "sku_item": sku_item.text,
        "codbar_item": codbar_item.text,
      });
      //queda pendiente la fecha de retiro y por ende la funcion correspondiente para calcularla
      mostrarMensaje("✅ Inventario agregado correctamente");
    } catch (e) {
      mostrarMensaje("❌ Error al guardar la información");
      print(e);
      return;
    }

    descript_item.clear();
    sku_item.clear();
    codbar_item.clear();
    await cargaritems();
  }

  //editar el inventario elegido
  /*Future<void> EditarInventario(Map<String, dynamic> invent) async {
    final nombreEditCtrl = TextEditingController(text: invent['nomb_invent']);
    String? categEditCtrl;
    String? nombreAdmin = await buscar_user(invent["admin_encarg"]);
    String? mombreApv = await buscar_user(invent["apv_encarg"]);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            "Editar Inventario",
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
                  nombreEditCtrl,
                  Icons.person_outline,
                  true,
                  "Nombre del inventario",
                ),
                const SizedBox(height: 10),
                _dropdownField(
                  label: invent["categ_invent"],
                  icon: Icons.work_outline,
                  value: categEditCtrl,
                  items: ["farmacia", "miscelaneos"],
                  onChanged: (nuevoValor) {
                    // Función cuando cambia
                    setState(() {
                      categEditCtrl = nuevoValor;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _dropdownField_rol(
                  label: nombreAdmin,
                  icon: Icons.person_outline,
                  value: adminEncargado,
                  items: list_admin,
                  onChanged: (nuevovalor) {
                    // Función cuando cambia
                    setState(() {
                      adminEncargado = nuevovalor;
                    });
                  },
                ),
                const SizedBox(height: 15),
                _dropdownField_rol(
                  label: mombreApv,
                  icon: Icons.person_outline,
                  value: apvEncargado,
                  items: list_apv,
                  onChanged: (nuevovalor) {
                    // Función cuando cambia
                    setState(() {
                      apvEncargado = nuevovalor;
                    });
                  },
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
                try {
                  await supabase
                      .from("inventarios")
                      .update({
                        "nomb_invent": nombreEditCtrl.text.isNotEmpty
                            ? nombreEditCtrl.text
                            : null,
                        "categ_invent": categEditCtrl ?? invent['categ_invent'],
                        "admin_encarg":
                            adminEncargado ?? invent['admin_encarg'],
                        "apv_encarg": apvEncargado ?? invent['apv_encarg'],
                      })
                      .eq("id_invent", invent["id_invent"]);
                  mostrarMensaje("✅ inventario actualizado correctamente");
                } catch (e) {
                  mostrarMensaje(
                    "❌ Error al modificar la información de este usuario ",
                  );
                }

                Navigator.pop(context);
                nombreCtrl.clear();
                setState(() {
                  categoryCtrl = null;
                  adminEncargado = null;
                  apvEncargado = null;
                });
                await cargarInventarios();
              },
              child: const Text("Guardar cambios"),
            ),
          ],
        );
      },
    );
  }*/

  //widget de un field tipo lista
  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: enabled ? onChanged : null,
      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF0077C8)),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF0077C8), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: !enabled,
        fillColor: !enabled ? Colors.grey[100] : null,
      ),
      validator: validator,
      style: TextStyle(color: enabled ? Colors.black87 : Colors.grey[600]),
    );
  }

  //estructura del input de busqueda
  Widget _buildSearchField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Color(0xFF0077C8)),
          hintText: "Buscar Items...",
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _filtrarItems();
                  },
                )
              : null,
        ),
        onChanged: (value) => _filtrarItems(),
      ),
    );
  }

  //cuerpo
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(
          "Gestión de ${widget.nomb_invent}",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0077C8),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Formulario para agregar un inventario
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
                      inputField_Text(
                        controller: nomb_item,
                        icon: Icons.info_outline,
                        enable: true,
                        label: "Nombre",
                      ),
                      const SizedBox(height: 15),
                      inputField_Text(
                        controller: descript_item,
                        icon: Icons.text_format_outlined,
                        enable: true,
                        label: "Descripción",
                      ),
                      const SizedBox(height: 15),
                      inputField_Text(
                        controller: sku_item,
                        icon: Icons.code_outlined,
                        enable: true,
                        label: "SKU Item",
                      ),
                      const SizedBox(height: 15),
                      inputField_Text(
                        controller: codbar_item,
                        icon: Icons.barcode_reader,
                        enable: true,
                        label: "Codigo de barra",
                      ),
                      const SizedBox(height: 15),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                          ),
                          label: const Text("Agregar Item"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0077C8),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            addItem();
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: Colors.white,
                          ),
                          label: const Text("Agregar lista de item por pdf"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0077C8),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            //AgregarInventario();
                            mostrarMensaje("Agregar inventario no esta listo");
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Encabezado de la lista con buscador
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Items (${itemsFiltrados.length})",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0077C8),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    Text(
                      "${itemsFiltrados.length} de ${items.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Buscador
              _buildSearchField(),
              const SizedBox(height: 15),
              // Lista de inventarios
              RefreshIndicator(
                onRefresh: cargaritems,
                child: itemsFiltrados.isEmpty
                    ? Container(
                        height: 150,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 50,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _searchController.text.isEmpty
                                  ? "No hay inventarios registrados"
                                  : "No se encontraron resultados",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_searchController.text.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _filtrarItems();
                                },
                                child: const Text(
                                  "Limpiar búsqueda",
                                  style: TextStyle(color: Color(0xFF0077C8)),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Column(
                        children: itemsFiltrados.map((item) {
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF0077C8),
                                child: Icon(
                                  Icons.medication_liquid_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                item['item_nomb'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                "${item['descript_item']}",
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_note_outlined,
                                      color: Colors.teal,
                                    ),
                                    onPressed: () {
                                      //EditarInventario(inventario);
                                      mostrarMensaje(
                                        "editar item no esta disponible aun",
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              // Espacio extra al final para evitar overflow
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
