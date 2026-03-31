import 'package:flutter/material.dart';

class UserHome extends StatelessWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Farmatodo - Usuario"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: const [
                  Icon(
                    Icons.local_pharmacy,
                    color: Colors.blueAccent,
                    size: 60,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Bienvenido a Farmatodo',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Aquí puedes consultar información sobre medicamentos, promociones y servicios de salud.',
                    style: TextStyle(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            /// Sección de botones con diseño moderno
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildOptionCard(
                  context,
                  icon: Icons.medication,
                  color: Colors.blueAccent.shade100,
                  title: 'Medicamentos',
                  subtitle: 'Consulta tu tratamiento',
                ),
                _buildOptionCard(
                  context,
                  icon: Icons.local_offer,
                  color: Colors.orangeAccent.shade100,
                  title: 'Promociones',
                  subtitle: 'Ofertas y descuentos',
                ),
                _buildOptionCard(
                  context,
                  icon: Icons.health_and_safety,
                  color: Colors.greenAccent.shade100,
                  title: 'Salud y Bienestar',
                  subtitle: 'Consejos útiles',
                ),
                _buildOptionCard(
                  context,
                  icon: Icons.support_agent,
                  color: Colors.purpleAccent.shade100,
                  title: 'Atención al Cliente',
                  subtitle: 'Contáctanos',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opción seleccionada: $title'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
