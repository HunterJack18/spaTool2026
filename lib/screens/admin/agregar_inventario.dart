import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:farmatodo/widget/widget_admin/agregar_item_individual.dart';
import 'package:farmatodo/screens/admin/agregar_item.dart';

class AgregarInventario extends StatefulWidget {
  const AgregarInventario({super.key});

  @override
  State<AgregarInventario> createState() => _AgregarInventarioState();
}

class _AgregarInventarioState extends State<AgregarInventario> {
  //intanciacion de supabase
  final SupabaseClient supabase = Supabase.instance.client;

  //variables locales
  final nombreCtrl = TextEditingController();
  String? categoryCtrl;
  String? adminEncargado;
  String? apvEncargado;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> inventarios = [];
  List<Map<String, dynamic>> inventariosFiltrados = [];
  List<Map<String, dynamic>> list_admin = [];
  List<Map<String, dynamic>> list_apv = [];

  @override
  void initState() {
    super.initState();
    cargarInventarios();
    cargarRol();
    _searchController.addListener(_filtrarInventarios);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void mostrarMensaje(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _filtrarInventarios() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        inventariosFiltrados = List.from(inventarios);
      } else {
        inventariosFiltrados = inventarios.where((inventario) {
          final nombre = inventario['nomb_invent'].toString().toLowerCase();
          final category = inventario['categ_invent'].toString().toLowerCase();
          return nombre.contains(query) || category.contains(query);
        }).toList();
      }
    });
  }

  //cargara una lista de los inventarios actuales
  Future<void> cargarInventarios() async {
    final data = await supabase.from('inventarios').select('*');
    setState(() {
      inventarios = data;
      inventariosFiltrados = List.from(inventarios);
    });
  }

  //cargara por individual una lista de los apv y admin registrados
  Future<void> cargarRol() async {
    final admin = await supabase
        .from("user_profiles")
        .select("nombre,auth_user_id")
        .eq("rol", "admin");

    final apv = await supabase
        .from("user_profiles")
        .select("nombre,auth_user_id")
        .eq("rol", "apv");
    setState(() {
      list_admin = admin.toList();
      list_apv = apv.toList();
    });
  }

  //buscar un usuario por id
  Future<String?> buscar_user(String auth_user_id) async {
    final user = await supabase
        .from("user_profiles")
        .select("nombre")
        .eq("auth_user_id", auth_user_id);

    return user.single["nombre"];
  }

  //agregar un inventario nuevo a la bd
  Future<void> AgregarInventario() async {
    if (nombreCtrl.text.isEmpty ||
        categoryCtrl == " " ||
        adminEncargado == " " ||
        apvEncargado == " ") {
      mostrarMensaje("⚠️ Completa todos los campos");
      return;
    }
    try {
      await supabase.from("inventarios").insert({
        "nomb_invent": nombreCtrl.text,
        "categ_invent": categoryCtrl,
        "admin_encarg": adminEncargado,
        "apv_encarg": apvEncargado,
      });

      mostrarMensaje("✅ Inventario agregado correctamente");
    } catch (e) {
      mostrarMensaje("❌ Error al guardar la información $e");
      return;
    }

    nombreCtrl.clear();
    setState(() {
      categoryCtrl = null;
      adminEncargado = null;
      apvEncargado = null;
    });
    await cargarInventarios();
  }

  //editar el inventario elegido
  Future<void> EditarInventario(Map<String, dynamic> invent) async {
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
  }

  //estructura de los inputs
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

  //widget de un field tipo lista para los roles cargados en supabase
  Widget _dropdownField_rol({
    required String? label,
    required IconData icon,
    required String? value,
    required List<Map<String, dynamic>> items,
    required void Function(String?) onChanged,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: enabled ? onChanged : null,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item["auth_user_id"],
          child: Text(item["nombre"]),
        );
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
          hintText: "Buscar inventarios...",
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
                    _filtrarInventarios();
                  },
                )
              : null,
        ),
        onChanged: (value) => _filtrarInventarios(),
      ),
    );
  }

  //cuerpo
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          "Gestión de Inventarios",
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
                      _inputField(
                        nombreCtrl,
                        Icons.person_outline,
                        true,
                        "Nombre del Inventario",
                      ),
                      const SizedBox(height: 10),
                      _dropdownField(
                        label: "Categoria",
                        icon: Icons.email_outlined,
                        value: categoryCtrl,
                        items: ["farmacia"],
                        onChanged: (nuevovalor) {
                          // Función cuando cambia
                          setState(() {
                            categoryCtrl = nuevovalor;
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      _dropdownField_rol(
                        label: "Supervisor encargado",
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
                        label: "Apv encargado",
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                          ),
                          label: const Text("Agregar Inventario"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0077C8),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            AgregarInventario();
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
                    "Inventarios (${inventariosFiltrados.length})",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0077C8),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    Text(
                      "${inventariosFiltrados.length} de ${inventarios.length}",
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
                onRefresh: cargarInventarios,
                child: inventariosFiltrados.isEmpty
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
                                  _filtrarInventarios();
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
                        children: inventariosFiltrados.map((inventario) {
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
                                  Icons.admin_panel_settings,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                inventario['nomb_invent'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(inventario['categ_invent']),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_note_outlined,
                                      color: Colors.teal,
                                    ),
                                    onPressed: () {
                                      EditarInventario(inventario);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.expand_outlined,
                                      color: Colors.teal,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AgregarItem(id_invent: inventario['id_invent'] ,nomb_invent: inventario['nomb_invent'],),
                                        ),
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
