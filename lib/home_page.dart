import 'dart:math';
import 'dart:ui';
import 'package:farmatodo/medicamentos_page2.dart';
import 'package:farmatodo/widget/IU/notification.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ajustes_page.dart';
import 'screens/admin/admin_home.dart';
import 'package:farmatodo/config/themes/themes.dart';

class HomePage extends StatefulWidget {
  final String nombre;
  final String rol;

  const HomePage({super.key, required this.nombre, required this.rol});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _bgCtrl;
  late final AnimationController _inCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final PageController _tipCtrl = PageController(viewportFraction: 0.92);
  int _tipIndex = 0;

  bool _cerrando = false;

  // ===== SUPABASE / DASHBOARD REAL =====
  final SupabaseClient _supabase = Supabase.instance.client;

  // idInvent dinámico (ya NO fijo)
  int? _idInventActual;
  bool _loadingInvent = true;

  // Resumen real
  bool _loadingResumen = true;
  int _stockCount = 0;
  int _porVencerCount = 0;

  // Lista real por vencer (para el modal)
  List<_PorVencerItem> _porVencerItems = [];

  // Config de "por vencer"
  static const int _diasPorVencer = 30;

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

    _tipCtrl.addListener(() {
      final v = (_tipCtrl.page ?? 0).round();
      if (v != _tipIndex) setState(() => _tipIndex = v);
    });

    // ✅ 1) Cargar inventario del usuario (idInvent dinámico)
    // ✅ 2) Luego cargar resumen real (stock / por vencer)
    _cargarInventarioUsuario();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _inCtrl.dispose();
    _tipCtrl.dispose();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return "U";
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
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

  // ================== FECHAS (DATE) ==================
  String _pgDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  int _diasParaVencer(DateTime fechaVenc) {
    final hoy = DateTime.now();
    final a = DateTime(hoy.year, hoy.month, hoy.day);
    final b = DateTime(fechaVenc.year, fechaVenc.month, fechaVenc.day);
    return b.difference(a).inDays;
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // ================== 1) INVENTARIO DINÁMICO POR USUARIO ==================
  Future<void> _cargarInventarioUsuario() async {
    try {
      setState(() => _loadingInvent = true);

      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _idInventActual = null;
          _loadingInvent = false;
        });
        _msg("Sesión no encontrada. Vuelve a iniciar sesión.");
        return;
      }

      final res = await _supabase
          .from('inventarios')
          .select('id_invent')
          .eq('admin_encarg', user.id)
          .limit(1)
          .maybeSingle();

      if (res == null) {
        setState(() {
          _idInventActual = null;
          _loadingInvent = false;
          _loadingResumen = false;
          _stockCount = 0;
          _porVencerCount = 0;
          _porVencerItems = [];
        });
        _msg("No tienes inventario asignado.");
        return;
      }

      final idInv = res['id_invent'];
      final parsed = idInv is int ? idInv : int.tryParse(idInv.toString());

      setState(() {
        _idInventActual = parsed;
        _loadingInvent = false;
      });

      // ✅ Con inventario asignado => cargar resumen real
      await _cargarResumenDashboard();
    } catch (e) {
      setState(() {
        _idInventActual = null;
        _loadingInvent = false;
        _loadingResumen = false;
      });
      _msg("Error cargando inventario: $e");
    }
  }

  // ================== 2) RESUMEN REAL (STOCK / POR VENCER) ==================
  Future<void> _cargarResumenDashboard() async {
    try {
      final inv = _idInventActual;
      if (inv == null) return;

      setState(() => _loadingResumen = true);

      final hoy = DateTime.now();
      final desde = _pgDate(DateTime(hoy.year, hoy.month, hoy.day));
      final hasta = _pgDate(
        DateTime(
          hoy.year,
          hoy.month,
          hoy.day,
        ).add(const Duration(days: _diasPorVencer)),
      );

      // Stock real: total items por inventario
      final stockRows = await _supabase
          .from('items')
          .select('id_item')
          .eq('id_invent', inv);

      final stockCount = (stockRows as List).length;

      // Por vencer real: fech_venc entre hoy y hoy+30 (no vencidos)
      final porVencerRows = await _supabase
          .from('Proximos_itemVencer')
          .select('*')
          .order('fech_venc', ascending: true);

      final list = (porVencerRows as List)
          .map((e) => _PorVencerItem.fromMap(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _stockCount = stockCount;
        _porVencerItems = list;
        _porVencerCount = list.length;
        _loadingResumen = false;
      });
    } catch (e) {
      setState(() => _loadingResumen = false);
      _msg('Error cargando resumen: $e');
    }
  }

  // ================== BOTTOMSHEET POR VENCER ==================
  void _mostrarPorVencerSheet() {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.78,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF061A2E).withOpacity(0.92),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withOpacity(0.10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.14),
                            ),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFFFD166),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Por vencer (≤ $_diasPorVencer días)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await _cargarResumenDashboard();
                            if (mounted) setState(() {});
                          },
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: Colors.white.withOpacity(0.85),
                          ),
                          tooltip: "Actualizar",
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.85),
                          ),
                          tooltip: "Cerrar",
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_idInventActual == null) ...[
                      const SizedBox(height: 18),
                      Text(
                        "No tienes inventario asignado.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.80),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (_loadingResumen) ...[
                      const SizedBox(height: 22),
                      const CircularProgressIndicator(color: Color(0xFF00B4D8)),
                      const SizedBox(height: 12),
                      Text(
                        'Cargando...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (_porVencerItems.isEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white.withOpacity(0.85),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No hay productos por vencer en los próximos $_diasPorVencer días.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.80),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _porVencerItems.length,
                          itemBuilder: (_, i) {
                            final it = _porVencerItems[i];
                            final dias = _diasParaVencer(it.fechaVenc);
                            final color = dias <= 7
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFFFD166);
                            final loteTxt = (it.numLote ?? '').trim().isEmpty
                                ? '—'
                                : it.numLote!.trim();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: color.withOpacity(0.18),
                                      border: Border.all(
                                        color: color.withOpacity(0.28),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.timer_rounded,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.nombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Lote: $loteTxt • Vence: ${_fmt(it.fechaVenc)}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.70,
                                            ),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: color.withOpacity(0.28),
                                      ),
                                    ),
                                    child: Text(
                                      '$dias d',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.95),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MedicamentosPage2(),
                            ),
                          );
                        },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B4D8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text(
                            "Ver en Medicamentos",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ================== PERFIL ==================
  void _mostrarPerfil(bool isAdmin) {
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF061A2E).withOpacity(0.92),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF037FC7), Color(0xFF00B4D8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF037FC7).withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _initials(widget.nombre),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAdmin ? "Administrador" : "Usuario",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _profileRow("Rol", widget.rol),
                    _profileRow("Estado", "Activo"),
                    _profileRow("Módulo", "Farmatodo"),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4D8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
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

  Widget _profileRow(String a, String b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a,
              style: TextStyle(
                color: Colors.white.withOpacity(0.70),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            b,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ================== UI PRINCIPAL ==================
  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.rol == 'admin';

    // Stats dinámicos
    final stats = <_Stat>[
      _Stat(
        label: "En stock",
        value: _loadingInvent || _loadingResumen
            ? "..."
            : _stockCount.toString(),
        icon: Icons.inventory_2_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MedicamentosPage2(),
            ),
          );
        },
      ),
      _Stat(
        label: "Por vencer",
        value: _loadingInvent || _loadingResumen
            ? "..."
            : _porVencerCount.toString(),
        icon: Icons.warning_amber_rounded,
        onTap: _mostrarPorVencerSheet,
      ),
      _Stat(
        label: "Agotados",
        value: "—",
        icon: Icons.remove_shopping_cart_rounded,
        onTap: () => _msg("Agotados: próximamente 😄"),
      ),
      if (isAdmin)
        _Stat(
          label: "Usuarios",
          value: "—",
          icon: Icons.group_rounded,
          onTap: () => _msg("Usuarios: próximamente 😄"),
        ),
    ];

    final tips = <_Tip>[
      const _Tip(
        title: "Centro de control",
        desc: "Revisa vencimientos y stock desde el dashboard.",
        icon: Icons.auto_awesome_rounded,
      ),
      const _Tip(
        title: "Controla vencimientos",
        desc: "Prioriza salida por lotes antes de 30 días.",
        icon: Icons.timer_rounded,
      ),
      _Tip(
        title: isAdmin ? "Administra permisos" : "Registra movimientos",
        desc: isAdmin
            ? "Gestiona módulos y usuarios desde Panel Control."
            : "Controla entradas/salidas para tener trazabilidad.",
        icon: isAdmin
            ? Icons.admin_panel_settings_rounded
            : Icons.receipt_long_rounded,
      ),
    ];

    final activity = <_Activity>[
      const _Activity(
        title: "Medicamento registrado",
        subtitle: "Hace 8 min · Inventario",
        icon: Icons.add_circle_rounded,
      ),
      const _Activity(
        title: "Alerta: próximo a vencer",
        subtitle: "Hace 25 min · Revisar lote",
        icon: Icons.warning_rounded,
      ),
      const _Activity(
        title: "Stock actualizado",
        subtitle: "Hoy · 14:20",
        icon: Icons.sync_rounded,
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildLeftDrawer(isAdmin),
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

              _glowBlob(
                x: 0.15 + (v * 0.03),
                y: 0.16,
                size: 280,
                opacity: 0.18,
              ),
              _glowBlob(
                x: 0.85 - (v * 0.03),
                y: 0.22,
                size: 240,
                opacity: 0.14,
              ),
              _glowBlob(
                x: 0.72,
                y: 0.88 - (v * 0.03),
                size: 340,
                opacity: 0.16,
              ),

              Positioned.fill(
                child: CustomPaint(painter: _ParticlePainter(progress: v)),
              ),

              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: _glassHomeCard(
                            v,
                            isAdmin,
                            stats,
                            tips,
                            activity,
                          ),
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

  // ================== DRAWER ==================
  Widget _buildLeftDrawer(bool isAdmin) {
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
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF037FC7), Color(0xFF00B4D8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF037FC7,
                                  ).withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _initials(widget.nombre),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
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
                                  widget.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isAdmin ? "Administrador" : "Usuario",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.70),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      _drawerItem(
                        icon: Icons.person_rounded,
                        title: "Mi Perfil",
                        subtitle: "Ver información",
                        onTap: () {
                          Navigator.pop(context);
                          _mostrarPerfil(isAdmin);
                        },
                      ),

                      _drawerItem(
                        icon: Icons.refresh_rounded,
                        title: "Actualizar",
                        subtitle: "Refrescar dashboard",
                        onTap: () async {
                          Navigator.pop(context);
                          await _cargarInventarioUsuario(); // inventario + resumen
                        },
                      ),

                      _drawerItem(
                        icon: Icons.settings_rounded,
                        title: "Ajustes",
                        subtitle: "Preferencias",
                        onTap: () {
                          Navigator.pop(context);
                          _msg("Ajustes: próximamente 😄");
                        },
                      ),

                      const Spacer(),

                      _drawerItem(
                        icon: Icons.logout_rounded,
                        title: "Cerrar sesión",
                        subtitle: "Salir de la cuenta",
                        danger: true,
                        onTap: () {
                          Navigator.pop(context);
                          _cerrarSesion();
                        },
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "v1.0 • Sistema interno",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFEF4444) : const Color(0xFF00B4D8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.10),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: Icon(icon, color: color),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================== GLASS CARD ==================
  Widget _glassHomeCard(
    double v,
    bool isAdmin,
    List<_Stat> stats,
    List<_Tip> tips,
    List<_Activity> activity,
  ) {
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
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  ),
                  AnimatedBuilder(
                    animation: _bgCtrl,
                    builder: (_, __) {
                      final dy = sin(v * 2 * pi) * 2.5;
                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF00B4D8,
                                ).withOpacity(0.20),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
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
                      );
                    },
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
                          "Bienvenido, ${widget.nombre}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _loadingInvent
                              ? "Cargando inventario..."
                              : (_idInventActual == null
                                    ? "Sin inventario asignado"
                                    : "Inventario #$_idInventActual"),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _pill(
                    text: isAdmin ? "ADMIN" : "USER",
                    icon: isAdmin
                        ? Icons.verified_rounded
                        : Icons.person_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _sectionTitle("Centro de control"),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: PageView.builder(
                  controller: _tipCtrl,
                  itemCount: tips.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (_, i) => _tipCard(tips[i]),
                ),
              ),
              const SizedBox(height: 8),
              _dots(tips.length, _tipIndex),

              const SizedBox(height: 14),

              _sectionTitle("Resumen"),
              const SizedBox(height: 10),
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: stats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _statCard(stats[i]),
                ),
              ),

              const SizedBox(height: 14),

              _sectionTitle("Módulos"),
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
                        title: "Gestión Proximos",
                        subtitle: "Inventario",
                        icon: Icons.local_pharmacy_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MedicamentosPage2(),
                            ),
                          );
                        },
                      ),
                      _moduleTile(
                        title: "Alertas",
                        subtitle: "Por vencer",
                        icon: Icons.notifications_active_rounded,
                        onTap: _mostrarPorVencerSheet,
                      ),
                      _moduleTile(
                        title: "Movimientos",
                        subtitle: "Historial",
                        icon: Icons.receipt_long_rounded,
                        onTap: () {
                          mostrarSnackBar.info(context,"Proximamente");
                        }, //_msg("Movimientos: próximamente 😄"),
                      ),
                      if (isAdmin)
                        _moduleTile(
                          title: "Panel Control",
                          subtitle: "Administrar",
                          icon: Icons.dashboard_customize_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminHome(),
                            ),
                          ),
                        ),

                      _moduleTile(
                        title: "Ajustes",
                        subtitle: "Preferencias",
                        icon: Icons.settings_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AjustesPage(),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 14),

              _sectionTitle("Actividad reciente"),
              const SizedBox(height: 10),
              ...activity.asMap().entries.map((e) {
                final isLast = e.key == activity.length - 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _timelineRow(e.value, isLast),
                );
              }),

              const SizedBox(height: 14),

              Text(
                'v1.0 • Sistema interno',
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

  Widget _pill({required String text, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00B4D8)),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ],
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

  Widget _dots(int count, int active) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(selected ? 0.90 : 0.45),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _tipCard(_Tip tip) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.12),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Icon(
                    tip.icon,
                    color: const Color(0xFF00B4D8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tip.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(_Stat s) {
    return _PressScale(
      onTap: s.onTap ?? () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withOpacity(0.12),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Icon(s.icon, color: const Color(0xFF00B4D8), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _moduleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _PressScale(
      onTap: onTap,
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
                        border: Border.all(
                          color: Colors.white.withOpacity(0.20),
                        ),
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
    );
  }

  Widget _timelineRow(_Activity a, bool isLast) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Icon(a.icon, color: const Color(0xFF00B4D8), size: 20),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 26,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      a.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.985 : 1,
        child: widget.child,
      ),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });
}

class _Tip {
  final String title;
  final String desc;
  final IconData icon;
  const _Tip({required this.title, required this.desc, required this.icon});
}

class _Activity {
  final String title;
  final String subtitle;
  final IconData icon;
  const _Activity({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _PorVencerItem {
  final String nombre;
  final String? numLote;
  final DateTime fechaVenc;

  _PorVencerItem({
    required this.nombre,
    required this.numLote,
    required this.fechaVenc,
  });

  factory _PorVencerItem.fromMap(Map<String, dynamic> map) {
    return _PorVencerItem(
      nombre: (map['nomb_item'] ?? '').toString(),
      numLote: map['num_lote']?.toString(),
      fechaVenc: DateTime.parse(map['fech_venc'].toString()),
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
