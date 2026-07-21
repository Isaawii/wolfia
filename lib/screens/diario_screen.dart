import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';

class DiarioScreen extends StatefulWidget {
  const DiarioScreen({super.key});

  @override
  State<DiarioScreen> createState() => _DiarioScreenState();
}

class _DiarioScreenState extends State<DiarioScreen> {
  final _db = WolfiaDb.instance;
  List<Sesion> _historial = [];
  List<Nota> _notas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final historial = await _db.getHistorial();
    final notas = await _db.getDiario();
    setState(() {
      _historial = historial;
      _notas = notas;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diario'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [Tab(text: 'Sesiones'), Tab(text: 'Notas')],
          ),
        ),
        body: TabBarView(
          children: [
            _SesionesTab(historial: _historial, onRefresh: _cargar),
            _NotasTab(notas: _notas, onRefresh: _cargar),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sesiones
// ---------------------------------------------------------------------------

class _SesionesTab extends StatelessWidget {
  final List<Sesion> historial;
  final Future<void> Function() onRefresh;
  const _SesionesTab({required this.historial, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: _vacio('Todavía no completaste ninguna sesión.'),
      );
    }

    final df = DateFormat('d MMM yyyy, HH:mm', 'es');
    final minutosTotales = historial.fold<int>(
        0, (a, s) => a + (s.duracionReal ?? s.duracionPlaneada));
    final promedio =
        historial.isEmpty ? 0 : (minutosTotales / historial.length).round();
    final finalizadas = historial.where((s) => s.estado == 'finalizada').length;

    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final estaSemana = historial
        .where((s) =>
            hoySinHora.difference(
                DateTime(s.fecha.year, s.fecha.month, s.fecha.day)) <
            const Duration(days: 7))
        .fold<int>(0, (a, s) => a + (s.duracionReal ?? s.duracionPlaneada));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.event_available,
                  value: '${historial.length}',
                  label: 'Sesiones',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  icon: Icons.timer_outlined,
                  value: '$minutosTotales',
                  label: 'Minutos totales',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  icon: Icons.bar_chart,
                  value: '$promedio',
                  label: 'Prom. min/sesión',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  value: '$finalizadas',
                  label: 'Finalizadas',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_view_week,
                  value: '$estaSemana',
                  label: 'Min. esta semana',
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...historial.map((s) => _SesionCard(sesion: s, df: df)),
        ],
      ),
    );
  }
}

class _SesionCard extends StatelessWidget {
  final Sesion sesion;
  final DateFormat df;
  const _SesionCard({required this.sesion, required this.df});

  @override
  Widget build(BuildContext context) {
    final color = _colorEstadoSesion(sesion.estado);
    final duracionReal = sesion.duracionReal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(_iconoEstadoSesion(sesion.estado),
                  color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    df.format(sesion.fecha),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _EstadoSesionBadge(sesion.estado),
                      _DuracionChip(
                        real: duracionReal,
                        planeada: sesion.duracionPlaneada,
                      ),
                    ],
                  ),
                  if (sesion.notas.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      sesion.notas,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notas
// ---------------------------------------------------------------------------

class _NotasTab extends StatelessWidget {
  final List<Nota> notas;
  final Future<void> Function() onRefresh;
  const _NotasTab({required this.notas, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (notas.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: _vacio('Todavía no escribiste ninguna nota.'),
      );
    }

    final df = DateFormat('d MMM yyyy, HH:mm', 'es');
    final vinculadas = notas
        .where((n) =>
            n.preparacionId != null ||
            n.segmentoId != null ||
            n.sesionId != null)
        .length;
    final hoy = DateTime.now();
    final estaSemana = notas
        .where((n) => hoy.difference(n.fecha) < const Duration(days: 7))
        .length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.edit_note,
                  value: '${notas.length}',
                  label: 'Notas',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  icon: Icons.link,
                  value: '$vinculadas',
                  label: 'Vinculadas',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_view_week,
                  value: '$estaSemana',
                  label: 'Esta semana',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...notas.map((n) => _NotaCard(nota: n, df: df)),
        ],
      ),
    );
  }
}

class _NotaCard extends StatelessWidget {
  final Nota nota;
  final DateFormat df;
  const _NotaCard({required this.nota, required this.df});

  @override
  Widget build(BuildContext context) {
    final vinculada = nota.preparacionId != null ||
        nota.segmentoId != null ||
        nota.sesionId != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nota.contenido, style: const TextStyle(color: AppColors.text)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  df.format(nota.fecha),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (vinculada)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link, size: 12, color: AppColors.info),
                        const SizedBox(width: 4),
                        Text(
                          nota.sesionId != null
                              ? 'De una sesión'
                              : nota.segmentoId != null
                                  ? 'De un segmento'
                                  : 'De una preparación',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.info),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers de estado y widgets compartidos (mismo lenguaje visual que
// repertorio_screen.dart / dominio_screen.dart)
// ---------------------------------------------------------------------------

Color _colorEstadoSesion(String estado) {
  switch (estado) {
    case 'finalizada':
      return AppColors.success;
    case 'en_curso':
      return AppColors.warning;
    default:
      return AppColors.textSecondary;
  }
}

IconData _iconoEstadoSesion(String estado) {
  switch (estado) {
    case 'finalizada':
      return Icons.check_circle;
    case 'en_curso':
      return Icons.play_circle_outline;
    default:
      return Icons.schedule;
  }
}

class _EstadoSesionBadge extends StatelessWidget {
  final String estado;
  const _EstadoSesionBadge(this.estado);

  @override
  Widget build(BuildContext context) {
    final color = _colorEstadoSesion(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoEstadoSesion(estado), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            estado,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Chip que compara minutos reales vs planeados. Verde si llegó o superó
/// lo planeado, ámbar si se quedó corto.
class _DuracionChip extends StatelessWidget {
  final int? real;
  final int planeada;
  const _DuracionChip({required this.real, required this.planeada});

  @override
  Widget build(BuildContext context) {
    final tieneReal = real != null;
    final color = !tieneReal
        ? AppColors.textSecondary
        : real! >= planeada
            ? AppColors.success
            : AppColors.warning;
    final texto = tieneReal ? '$real / $planeada min' : '$planeada min (plan)';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de resumen para el encabezado tipo dashboard.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

Widget _vacio(String texto) {
  return LayoutBuilder(
    builder: (ctx, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(texto,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ),
    ),
  );
}
