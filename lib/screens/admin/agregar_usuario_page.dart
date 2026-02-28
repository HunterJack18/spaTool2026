import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgregarUsuarioPage extends StatefulWidget {
  const AgregarUsuarioPage({super.key});

  @override
  State<AgregarUsuarioPage> createState() => _AgregarUsuarioPageState();
}

class _AgregarUsuarioPageState extends State<AgregarUsuarioPage> {
  //intanciacion de supabase
  final SupabaseClient supabase = Supabase.instance.client;

  final nombreCtrl = TextEditingController();
  final mailCtrl = TextEditingController();
  final codCtrl = TextEditingController();
  final cedCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String? rolCtrl;
  List<Map<String, dynamic>> usuarios = [];
  List<Map<String, dynamic>> usuariosFiltrados = [];

  @override
  void initState() {
    super.initState();
    cargarUsuarios();
    _searchController.addListener(_filtrarUsuarios);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void mostrarMensaje(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _filtrarUsuarios() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        usuariosFiltrados = List.from(usuarios);
      } else {
        usuariosFiltrados = usuarios.where((usuario) {
          final nombre = usuario['nombre'].toString().toLowerCase();
          final cod_user = usuario['cod_user'].toString().toLowerCase();
          final rol = usuario['rol'].toString().toLowerCase();
          return nombre.contains(query) ||
              cod_user.contains(query) ||
              rol.contains(query);
        }).toList();
      }
    });
  }

  Future<void> cargarUsuarios() async {
    final data = await supabase.from('user_profiles').select('*');
    setState(() {
      usuarios = data;
      usuariosFiltrados = List.from(usuarios);
    });
  }

  Future<void> agregarUsuario() async {
    if (nombreCtrl.text.isEmpty ||
        codCtrl.text.isEmpty ||
        cedCtrl.text.isEmpty ||
        mailCtrl.text.isEmpty) {
      mostrarMensaje("⚠️ Completa todos los campos");
      return;
    }
    try {
      final singup = await supabase.auth.signUp(
        email: mailCtrl.text,
        password: 'Griselda.195*',
        data: {'nombre': nombreCtrl.text, 'rol': rolCtrl},
      );

      final userId = singup.user!.id;

      await supabase
          .from("info_users")
          .update({'cedula': cedCtrl.text, 'cod_user': codCtrl.text})
          .eq("user_id", userId);

      mostrarMensaje("✅ Usuario agregado correctamente");
    } catch (e) {
      print("❌ Error al guardar la información");
      return;
    }

    mailCtrl.clear();
    nombreCtrl.clear();
    codCtrl.clear();
    cedCtrl.clear();

    await cargarUsuarios();
  }

  Future<void> disableUsuario(String id, String estado) async {
    String valor;
    try {
      if (estado == 'activo') {
        valor = "inactivo";
      } else {
        valor = "activo";
      }
      await supabase
          .from('info_users')
          .update({'estado': valor})
          .eq('user_id', id);

      await cargarUsuarios();
      mostrarMensaje("✅ Usuario modificado correctamente");
    } catch (e) {
      mostrarMensaje("❌ error al deshabilitar a este usuario $e");
    }
  }

  Future<void> editarUsuario(Map<String, dynamic> usuario) async {
    final nombreEditCtrl = TextEditingController(text: usuario['nombre']);
    final correoEditCtrl = TextEditingController(text: usuario['email']);
    final codCtrl = TextEditingController(text: usuario['cod_user']);
    final cedCtrl = TextEditingController(text: usuario['cedula']);
    final rolCtrl = TextEditingController(text: usuario['rol']);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            "Editar Usuario",
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
                  "Nombre completo",
                ),
                const SizedBox(height: 10),
                _inputField(
                  correoEditCtrl,
                  Icons.email_outlined,
                  false,
                  "Correo electrónico",
                ),
                const SizedBox(height: 10),
                _inputField(
                  codCtrl,
                  Icons.work_outline,
                  true,
                  "Código de Colaborador",
                ),
                const SizedBox(height: 10),
                _inputField(cedCtrl, Icons.work_outline, true, "Cédula"),
                const SizedBox(height: 10),
                _inputField(rolCtrl, Icons.work_outline, false, "Cargo"),
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
                      .from("info_users")
                      .update({
                        "nombre": nombreEditCtrl.text,
                        "cod_user": codCtrl.text,
                        "cedula": cedCtrl.text,
                      })
                      .eq("user_id", usuario["auth_user_id"]);
                  mostrarMensaje("✅ Usuario actualizado correctamente");
                } catch (e) {
                  mostrarMensaje(
                    "❌ Error al modificar la información de este usuario ",
                  );
                }
                Navigator.pop(context);
                await cargarUsuarios();
              },
              child: const Text("Guardar cambios"),
            ),
          ],
        );
      },
    );
  }

  //widget field
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
      items: items.map((String item) {
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

  Widget _buildSearchField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Color(0xFF0077C8)),
          hintText: "Buscar usuarios...",
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
                    _filtrarUsuarios();
                  },
                )
              : null,
        ),
        onChanged: (value) => _filtrarUsuarios(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          "Gestión de Usuarios",
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
              // Formulario para agregar usuario
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
                        "Primer Nombre y Apellido",
                      ),
                      const SizedBox(height: 10),
                      _inputField(
                        mailCtrl,
                        Icons.mail_outline,
                        true,
                        "Correo Electrónico",
                      ),
                      const SizedBox(height: 10),
                      _inputField(
                        codCtrl,
                        Icons.description_outlined,
                        true,
                        "Código del Colaborador",
                      ),
                      const SizedBox(height: 10),
                      _inputField(
                        cedCtrl,
                        Icons.description_outlined,
                        true,
                        "Cédula",
                      ),
                      const SizedBox(height: 10),
                      _dropdownField(
                        label: "Cargos disponibles",
                        icon: Icons.work_outline,
                        value: rolCtrl,
                        items: ["admin", "apv"],
                        onChanged: (nuevoValor) {
                          // Función cuando cambia
                          setState(() {
                            rolCtrl = nuevoValor;
                          });
                        },
                        validator: (String? valorSeleccionado) {
                          if (valorSeleccionado == null ||
                              valorSeleccionado.isEmpty) {
                            mostrarMensaje('Por favor seleccione un rol');
                          }
                        },
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                          ),
                          label: const Text("Agregar Usuario"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0077C8),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: agregarUsuario,
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
                    "Usuarios (${usuariosFiltrados.length})",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0077C8),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    Text(
                      "${usuariosFiltrados.length} de ${usuarios.length}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Buscador
              _buildSearchField(),
              const SizedBox(height: 15),

              // Lista de usuarios
              RefreshIndicator(
                onRefresh: cargarUsuarios,
                child: usuariosFiltrados.isEmpty
                    ? Container(
                        height: 150,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 50,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _searchController.text.isEmpty
                                  ? "No hay usuarios registrados"
                                  : "No se encontraron resultados",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.withOpacity(0.7),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _filtrarUsuarios();
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
                        children: usuariosFiltrados.map((usuario) {
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF0077C8),
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(
                                usuario['nombre'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(usuario['rol']),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.teal,
                                    ),
                                    onPressed: () => editarUsuario(usuario),
                                  ),

                                  IconButton(
                                    icon: Icon(
                                      usuario['estado'] == 'activo'
                                          ? Icons.lock
                                          : Icons.lock_open,
                                      color: usuario['estado'] == 'inactivo'
                                          ? Colors.redAccent
                                          : Colors.green,
                                    ),
                                    onPressed: () => disableUsuario(
                                      usuario['auth_user_id'],
                                      usuario['estado'],
                                    ),
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
