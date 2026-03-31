import 'dart:math';
import 'dart:ui';
import 'package:farmatodo/medicamentos_page2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:farmatodo/screens/admin/agregar_inventario.dart';
import 'agregar_usuario_page.dart';
import '../../ajustes_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _bgCtrl;
  late final AnimationController _inCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _pressed = false;
  bool _cerrando = false;

  // ===== PERFIL (TU TABLA info_users USA user_id) =====
  String _nombrePerfil = "";
  String _rolPerfil = "";
  bool _loadingPerfil = true;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _inCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fade = CurvedAnimation(parent: _inCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _inCtrl, curve: Curves.easeOutCubic));

    _inCtrl.forward();

    _cargarPerfil();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _inCtrl.dispose();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return "US";
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  String _rolLabel(String rol) {
    final r = rol.trim().toLowerCase();
    if (r == 'admin') return 'Administrador';
    if (r == 'apv') return 'APV';
    if (r.isEmpty) return 'Usuario';
    return r.toUpperCase();
  }

  // ✅ PERFIL REAL: se busca por user_id (según tu captura)
  Future<void> _cargarPerfil() async {
    try {
      setState(() => _loadingPerfil = true);

      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _nombrePerfil = "";
          _rolPerfil = "";
          _loadingPerfil = false;
        });
        _msg("Sesión no válida. Inicia sesión de nuevo.");
        Navigator.pushReplacementNamed(context, 'LoginPage');
        return;
      }

      final res = await _supabase
          .from('info_users')
          .select('nombre, rol')
          .eq('user_id', user.id)
          .maybeSingle();

      if (res == null) {
        // fallback para que nunca se vea vacío
        final fallbackName = user.email?.split('@').first ?? "Usuario";
        setState(() {
          _nombrePerfil = fallbackName;
          _rolPerfil = "admin";
          _loadingPerfil = false;
        });
        return;
      }

      setState(() {
        _nombrePerfil = (res['nombre'] ?? '').toString().trim();
        _rolPerfil = (res['rol'] ?? '').toString().trim();
        _loadingPerfil = false;
      });
    } catch (e) {
      setState(() => _loadingPerfil = false);
      _msg("Error cargando perfil: $e");
    }
  }

  Future<void> _cerrarSesion() async {
    if (_cerrando) return;
    setState(() => _cerrando = true);

    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, 'LoginPage');
    } catch (e) {
      _msg('Error al cerrar sesión: $e');
    }

    if (mounted) setState(() => _cerrando = false);
  }

  Future<void> _abrirMedicamentos() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión no válida. Inicia sesión de nuevo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacementNamed(context, 'LoginPage');
        return;
      }

      final res = await _supabase
          .from('inventarios')
          .select('id_invent')
          .eq('admin_encarg', user.id)
          .limit(1)
          .maybeSingle();

      if (res == null || res['id_invent'] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes inventario asignado. Ve a Inventarios y asígnate uno.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final int idInvent = (res['id_invent'] as num).toInt();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MedicamentosPage2()),
      );
    } catch (e) {
      _msg('Error abriendo medicamentos: $e');
    }
  }

  // ✅ MI PERFIL (como tu imagen)
  void _mostrarPerfil() {
    final name = _loadingPerfil ? "Cargando..." : (_nombrePerfil.isEmpty ? "Sin nombre" : _nombrePerfil);
    final rolLabel = _rolLabel(_loadingPerfil ? "" : _rolPerfil);
    final initials = _initialsFromName(name);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.55,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF061A2E).withOpacity(0.92),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00B4D8),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rolLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 18),

                    _perfilFila("Rol", _rolPerfil.isEmpty ? "—" : _rolPerfil),
                    const SizedBox(height: 10),
                    _perfilFila("Estado", "Activo"),
                    const SizedBox(height: 10),
                    _perfilFila("Módulo", "Farmatodo"),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4D8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          "Listo",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _perfilFila(String left, String right) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Text(
            left,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ===== DRAWER DERECHO (como tu imagen) =====
  Widget _buildRightDrawerLikeImage() {
    final name = _loadingPerfil ? "Cargando..." : (_nombrePerfil.isEmpty ? "Usuario" : _nombrePerfil);
    final initials = _initialsFromName(name);
    final rolLabel = _rolLabel(_loadingPerfil ? "" : _rolPerfil);

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF061A2E), Color(0xFF072744)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00B4D8),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rolLabel,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.70),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _drawerCardItem(
                    icon: Icons.person_rounded,
                    title: "Mi Perfil",
                    subtitle: "Ver información",
                    onTap: () {
                      Navigator.pop(context);
                      _mostrarPerfil();
                    },
                  ),
                  _drawerCardItem(
                    icon: Icons.refresh_rounded,
                    title: "Actualizar",
                    subtitle: "Refrescar dashboard",
                    onTap: () async {
                      Navigator.pop(context);
                      await _cargarPerfil();
                      _msg("Actualizado ✅");
                    },
                  ),
                  _drawerCardItem(
                    icon: Icons.settings_rounded,
                    title: "Ajustes",
                    subtitle: "Preferencias",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AjustesPage()),
                      );
                    },
                  ),

                  const Spacer(),

                  _drawerCardItem(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: "Cerrar sesión",
                    subtitle: "Salir de la cuenta",
                    onTap: () async {
                      Navigator.pop(context);
                      await _cerrarSesion();
                    },
                  ),

                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "v1.0 • Sistema interno",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerCardItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final c = iconColor ?? const Color(0xFF00B4D8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Icon(icon, color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.68),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF061A2E),
      endDrawer: _buildRightDrawerLikeImage(),
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (context, _) {
          final v = _bgCtrl.value;

          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [
                      Color(0xFF061A2E),
                      Color(0xFF072744),
                      Color(0xFF061A2E),
                    ],
                    stops: [0.0, 0.55 + (v * 0.12), 1.0],
                  ),
                ),
              ),

              _glowBlob(x: 0.18 + (v * 0.03), y: 0.18, size: 280, opacity: 0.18),
              _glowBlob(x: 0.86 - (v * 0.03), y: 0.22, size: 240, opacity: 0.14),
              _glowBlob(x: 0.72, y: 0.88 - (v * 0.03), size: 340, opacity: 0.16),

              Positioned.fill(
                child: CustomPaint(
                  painter: _ParticlePainter(progress: v),
                ),
              ),

              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: _glassAdminCard(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _glassAdminCard() {
    final titleName = _loadingPerfil
        ? "Cargando..."
        : (_nombrePerfil.isEmpty ? "Panel Administrativo" : _nombrePerfil);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: "Volver",
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white.withOpacity(0.9),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withOpacity(0.12),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/farmatodo.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.local_pharmacy,
                          color: Color(0xFF00B4D8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Farmatodo",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          titleName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Menú",
                    icon: const Icon(Icons.menu_rounded),
                    color: Colors.white.withOpacity(0.9),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              _sectionTitle("Acciones rápidas"),
              const SizedBox(height: 10),

              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 480;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: wide ? 3 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05,
                    children: [
                      _moduleTile(
                        title: "Usuarios",
                        subtitle: "Registrar / Inhabilitar",
                        icon: Icons.people_alt_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AgregarUsuarioPage()),
                        ),
                      ),
                      _moduleTile(
                        title: "Inventarios",
                        subtitle: "Gestión",
                        icon: Icons.admin_panel_settings_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AgregarInventario()),
                        ),
                      ),
                      _moduleTile(
                        title: "Registro",
                        subtitle: "Medicamentos",
                        icon: Icons.local_pharmacy_rounded,
                        onTap: _abrirMedicamentos,
                      ),
                      _moduleTile(
                        title: "Configuración",
                        subtitle: "Ajustes del sistema",
                        icon: Icons.settings_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AjustesPage()),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 14),
              Text(
                'Farmatodo © 2025 • Panel Administrativo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [Color(0xFF037FC7), Color(0xFF00B4D8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _moduleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.985 : 1,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF037FC7), Color(0xFF00B4D8)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF037FC7).withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -28,
                right: -32,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.14),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.16),
                          border: Border.all(color: Colors.white.withOpacity(0.20)),
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.80),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _glowBlob({
    required double x,
    required double y,
    required double size,
    required double opacity,
  }) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Positioned(
      left: (w * x) - (size / 2),
      top: (h * y) - (size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFF00B4D8).withOpacity(opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 28; i++) {
      final fx = (sin(i * 12.3) * 0.5 + 0.5);
      final fy = (cos(i * 9.7) * 0.5 + 0.5);

      final dx = size.width * ((fx + (progress * 0.08)) % 1.0);
      final dy = size.height * ((fy + (progress * 0.10)) % 1.0);

      final r = 1.2 + (sin((progress * 2 * pi) + i) + 1) * 0.6;

      paint.color = Colors.white.withOpacity(0.05 + (i % 6) * 0.01);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
