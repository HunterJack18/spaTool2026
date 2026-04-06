import 'package:farmatodo/widget/IU/snackBar.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:farmatodo/config/themes/themes.dart';
import 'package:farmatodo/models/medicamento.dart';

// ============================================================
// TARJETA DE SEGUIMIENTO
// ============================================================

class TarjetaSeguimiento extends StatelessWidget {
  final ItemSeguimiento seguimiento;
  final ItemMedicamento? itemInfo;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;
  final int diasCerca;

  const TarjetaSeguimiento({
    super.key,
    required this.seguimiento,
    this.itemInfo,
    this.onEditar,
    this.onEliminar,
    this.diasCerca = 10,
  });

  // Función para calcular días hasta DE RETIRO
  int _diasParaVencer(DateTime? fechaVenc) {
    if (fechaVenc == null)
      return 999999; // Valor grande para que no se considere cerca
    final hoy = DateTime.now();
    final a = DateTime(hoy.year, hoy.month, hoy.day);
    final b = DateTime(fechaVenc.year, fechaVenc.month, fechaVenc.day);
    return b.difference(a).inDays;
  }

  // Formatear fecha para mostrar
  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'No disponible';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  // Calcular mensaje de días restantes
  String _calcularDiasRestantes(DateTime? fechaVencimiento) {
    if (fechaVencimiento == null) return 'Fecha no disponible';
    final d = _diasParaVencer(fechaVencimiento);
    if (d < 0) return 'Vencido hace ${d.abs()} días';
    if (d == 0) return 'Retirar hoy';
    if (d == 1) return 'Retirar en 1 día';
    return 'Retirar en $d días';
  }

  // Obtener información del item (nombre, etc.)
  String get _nombreItem {
    if (itemInfo != null) {
      return itemInfo!.item_nomb;
    }
    return 'Item ID: ${seguimiento.idItem}';
  }

  String get _descripcionItem {
    return itemInfo?.descript_item ?? '';
  }

  String get _codigoItem {
    return itemInfo?.codbar_item?.toString() ?? '—';
  }

  String get _skuItem {
    return itemInfo?.sku_item?.toString() ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final dias = _diasParaVencer(seguimiento.fechaRetiro);
    final vencido = dias < 0;
    final cerca = dias <= diasCerca;

    Color estadoColor = ColorTheme[2]; // verde para OK
    IconData estadoIcon = Icons.check_circle_rounded;
    String estadoTexto = 'En buen estado';

    if (vencido) {
      estadoColor = ColorTheme[4]; // rojo
      estadoIcon = Icons.error_rounded;
      estadoTexto = 'VENCIDO';
    } else if (cerca) {
      estadoColor = ColorTheme[3]; // warring
      estadoIcon = Icons.warning_rounded;
      estadoTexto = '¡CERCA DE RETIRAR!';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ColorTheme[6],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estadoColor.withOpacity(0.40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con icono y nombre
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: estadoColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombreItem,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
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
                            style: TextStyle(
                              color: estadoColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: estadoColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _calcularDiasRestantes(seguimiento.fechaRetiro),
                          style: TextStyle(
                            color: estadoColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Menú de opciones
                if (onEditar != null || onEliminar != null)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'editar' && onEditar != null) onEditar!();
                      if (v == 'eliminar' && onEliminar != null) onEliminar!();
                    },
                    icon: Icon(Icons.more_vert_rounded, color: ColorTheme[1]),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      if (onEditar != null)
                        PopupMenuItem<String>(
                          value: 'editar',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, color: ColorTheme[0]),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                      if (onEliminar != null)
                        PopupMenuItem<String>(
                          value: 'eliminar',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: ColorTheme[4],
                              ),
                              SizedBox(width: 8),
                              Text('Eliminar'),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),

            // Descripción (si existe)
            if (_descripcionItem.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _descripcionItem,
                style: TextStyle(
                  color: ColorTheme[1].withOpacity(0.9),
                  height: 1.35,
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Información de código y SKU
            Row(
              children: [
                Expanded(child: _miniInfo('Código', _codigoItem)),
                const SizedBox(width: 12),
                Expanded(child: _miniInfo('SKU', _skuItem)),
              ],
            ),

            const SizedBox(height: 14),

            // Fecha de vencimiento
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: estadoColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: estadoColor.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: estadoColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vence el ${_formatearFecha(seguimiento.fechaVenc)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: estadoColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Fecha de retiro
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ColorTheme[0].withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorTheme[0].withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: ColorTheme[0],
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Retirar el ${_formatearFecha(seguimiento.fechaRetiro)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: ColorTheme[0],
                      ),
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

  Widget _miniInfo(String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: ColorTheme[1].withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: ColorTheme[1],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LISTA ANIMADA DE SEGUIMIENTOS
// ============================================================

class ListaSeguimientos extends StatelessWidget {
  final List<ItemSeguimiento> seguimientos;
  final Map<String, ItemMedicamento> itemsInfo;
  final VoidCallback? onRefresh;
  final Future<bool> Function(ItemSeguimiento)? onEliminar;
  final Function(ItemSeguimiento)? onEditar;
  final int diasCerca;

  const ListaSeguimientos({
    super.key,
    required this.seguimientos,
    required this.itemsInfo,
    this.onRefresh,
    this.onEliminar,
    this.onEditar,
    this.diasCerca = 15,
  });

  @override
  Widget build(BuildContext context) {
    final key = ValueKey('lista_${seguimientos.length}');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        final fade = FadeTransition(opacity: anim, child: child);
        final slide = SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(anim),
          child: fade,
        );
        return slide;
      },
      child: ListView.builder(
        key: key,
        padding: const EdgeInsets.all(16),
        itemCount: seguimientos.length,
        itemBuilder: (context, index) {
          final seguimiento = seguimientos[index];
          final itemInfo = itemsInfo[seguimiento.idItem];

          return Dismissible(
            key: ValueKey('dismiss_${seguimiento.idSeguimiento}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: onEliminar != null
                ? (_) async => await onEliminar!(seguimiento)
                : null,
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: ColorTheme[4].withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ColorTheme[4].withOpacity(0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.delete_outline_rounded, color: ColorTheme[4]),
                  const SizedBox(width: 8),
                  Text(
                    'Eliminar',
                    style: TextStyle(
                      color: ColorTheme[4],
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            child: TarjetaSeguimiento(
              seguimiento: seguimiento,
              itemInfo: itemInfo,
              diasCerca: diasCerca,
              onEditar: onEditar != null ? () => onEditar!(seguimiento) : null,
              onEliminar: onEliminar != null
                  ? () async => await onEliminar!(seguimiento)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
