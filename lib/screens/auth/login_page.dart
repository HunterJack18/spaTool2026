import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home_page.dart';

class LoginPage extends StatefulWidget {
  static const String routname = 'LoginPage';
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final correoCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool cargando = false;
  bool verPassword = false;

  // Animaciones
  late final AnimationController _bgCtrl; 
  late final AnimationController _inCtrl; 
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

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
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _inCtrl.dispose();
    correoCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  void mostrarMensaje(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> iniciarSesion() async {
    setState(() => cargando = true);

    final correo = correoCtrl.text.trim();
    final password = passCtrl.text.trim();
    final supabase = Supabase.instance.client;

    if (correo.isEmpty || password.isEmpty) {
      mostrarMensaje('Por favor completa todos los campos');
      if (mounted) setState(() => cargando = false);
      return;
    }

    try {
      final resp = await supabase.auth.signInWithPassword(
        email: correo,
        password: password,
      );

      final user = resp.user;
      if (user == null) {
        mostrarMensaje('No se pudo iniciar sesión. Intenta nuevamente.');
        if (mounted) setState(() => cargando = false);
        return;
      }

      final userData = await supabase
          .from('info_users')
          .select('estado, nombre, rol')
          .eq('user_id', user.id)
          .maybeSingle();

      if (userData == null) {
        mostrarMensaje('Tu usuario no tiene perfil creado (info_users).');
        if (mounted) setState(() => cargando = false);
        return;
      }

      if ((userData['estado'] ?? '').toString() != 'activo') {
        mostrarMensaje(
          'Su cuenta se encuentra inhabilitada, comunicarse con el supervisor',
        );
        if (mounted) setState(() => cargando = false);
        return;
      }

      final nombre = (userData['nombre'] ?? '').toString();
      final rol = (userData['rol'] ?? '').toString();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(nombre: nombre, rol: rol)),
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        mostrarMensaje('Credenciales inválidas. Verifica correo y contraseña.');
      } else if (msg.contains('email not confirmed')) {
        mostrarMensaje('Correo no confirmado. Revisa tu email.');
      } else {
        mostrarMensaje('Error de autenticación: ${e.message}');
      }
    } catch (_) {
      mostrarMensaje('Error en el login. Intenta nuevamente.');
    }

    if (mounted) setState(() => cargando = false);
  }

  InputDecoration _decor({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF00B4D8), width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (context, _) {
          final v = _bgCtrl.value;

          return Stack(
            children: [
              // Fondo Farmatodo Futurista
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

              // Glow blobs
              _glowBlob(x: 0.15 + (v * 0.03), y: 0.18, size: 260, opacity: 0.18),
              _glowBlob(x: 0.85 - (v * 0.03), y: 0.22, size: 220, opacity: 0.14),
              _glowBlob(x: 0.70, y: 0.85 - (v * 0.03), size: 320, opacity: 0.16),

              // Partículas
              Positioned.fill(
                child: CustomPaint(
                  painter: _ParticlePainter(progress: v),
                ),
              ),

              // Card
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: _glassCard(v),
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

  Widget _glassCard(double v) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(22),
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo flotante
                AnimatedBuilder(
                  animation: _bgCtrl,
                  builder: (_, __) {
                    final dy = sin(v * 2 * pi) * 3;
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: Container(
                        height: 96,
                        width: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          color: Colors.white.withOpacity(0.12),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00B4D8).withOpacity(0.22),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.asset(
                            'assets/images/farmatodo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.local_pharmacy,
                              size: 50,
                              color: Color(0xFF00B4D8),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                const Text(
                  'Farmatodo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Inicio de sesión',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 22),

                // Email
                TextFormField(
                  controller: correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  style: const TextStyle(color: Colors.white),
                  decoration: _decor(
                    label: 'Correo',
                    icon: Icons.email_outlined,
                    hint: 'correo@dominio.com',
                  ).copyWith(
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                    prefixIconColor: Colors.white.withOpacity(0.70),
                    suffixIconColor: Colors.white.withOpacity(0.70),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Ingresa tu correo';
                    if (!value.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Password
                TextFormField(
                  controller: passCtrl,
                  obscureText: !verPassword,
                  autofillHints: const [AutofillHints.password],
                  style: const TextStyle(color: Colors.white),
                  decoration: _decor(
                    label: 'Contraseña',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => verPassword = !verPassword),
                      icon: Icon(
                        verPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white.withOpacity(0.70),
                      ),
                    ),
                  ).copyWith(
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
                    prefixIconColor: Colors.white.withOpacity(0.70),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Ingresa tu contraseña';
                    if (value.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // Botón Farmatodo con Shine
                GestureDetector(
                  onTap: cargando
                      ? null
                      : () {
                          final ok = _formKey.currentState?.validate() ?? false;
                          if (!ok) return;
                          iniciarSesion();
                        },
                  child: Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF037FC7),
                          Color(0xFF00B4D8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF037FC7).withOpacity(0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Shine
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _bgCtrl,
                            builder: (_, __) {
                              final t = _bgCtrl.value;
                              return Opacity(
                                opacity: 0.22,
                                child: Transform.translate(
                                  offset: Offset((t * 280) - 140, 0),
                                  child: Transform.rotate(
                                    angle: -0.35,
                                    child: Container(
                                      width: 140,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(0.55),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: cargando
                                ? const SizedBox(
                                    key: ValueKey('loading'),
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.6,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    key: ValueKey('text'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login, color: Colors.white),
                                      SizedBox(width: 10),
                                      Text(
                                        'Iniciar Sesión',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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
