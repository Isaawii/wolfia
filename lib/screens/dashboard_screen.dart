import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../services/session_generator.dart';
import '../theme.dart';
import 'sesion_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = WolfiaDb.instance;
  Sesion? _sesionEnCurso;
  List<Preparacion> _activas = [];
  List<Sesion> _historial = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final sesion = await _db.getSesionEnCurso();
    final activas = await _db.getPreparacionesActivas();
    final historial = await _db.getHistorial();
    setState(() {
      _sesionEnCurso = sesion;
      _activas = activas;
      _historial = historial;
      _cargando = false;
    });
  }

  Future<void> _generarSesion(int minutos) async {
    final navCtx = context;
    final gen = SessionGenerator();
    final sesion = await gen.generar(minutosDisponibles: minutos);
    if (!mounted) return;
    Navigator.of(navCtx).push(MaterialPageRoute(
      builder: (_) => SesionActivaScreen(sesionId: sesion.id),
    ));
    _cargar();
  }

  void _preguntarDuracion() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Cuánto tiempo tenés hoy?',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [15, 30, 45, 60, 90].map((m) {
                return ActionChip(
                  label: Text('$m min'),
                  onPressed: () async {
                    final parentContext = context;
                    Navigator.pop(ctx);
                    // Show preview before creating
                    final gen = SessionGenerator();
                    final plan = await gen.planificar(minutosDisponibles: m);
                    if (!mounted) return;
                    await showModalBottomSheet(
                      context: parentContext,
                      backgroundColor: AppColors.surface,
                      isScrollControlled: true,
                      builder: (previewCtx) => DraggableScrollableSheet(
                        initialChildSize: 0.6,
                        expand: false,
                        builder: (previewCtx, sc) => ListView(
                          controller: sc,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          children: [
                            Text('Plan de sesión ($m min)',
                                style:
                                    Theme.of(previewCtx).textTheme.titleLarge),
                            const SizedBox(height: AppSpacing.md),
                            if ((plan['tareas'] as List).isEmpty)
                              const Text(
                                  'No hay tareas planificadas para este tiempo.'),
                            ...((plan['tareas'] as List<Tarea>).map((t) =>
                                ListTile(
                                  title: Text(
                                      t.tituloObjetivo ?? t.tituloPreparacion),
                                  subtitle: Text(
                                    '${t.tituloPreparacion}${t.tituloSegmento != null ? ' · ${t.tituloSegmento}' : ''}',
                                  ),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${t.minutosPlaneados} min'),
                                      Text(
                                        'hasta ${_formatearFin(t.minutosPlaneados)}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ))),
                            const SizedBox(height: AppSpacing.md),
                            Row(children: [
                              Expanded(
                                  child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(previewCtx);
                                        _generarSesion(m);
                                      },
                                      child: const Text('Crear sesión'))),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                  child: OutlinedButton(
                                      onPressed: () async {
                                        // Ask how many sessions to create
                                        final dialogContext = previewCtx;
                                        final qty = await showDialog<int>(
                                            context: dialogContext,
                                            builder: (dCtx) {
                                              final ctrl =
                                                  TextEditingController(
                                                      text: '1');
                                              return AlertDialog(
                                                backgroundColor:
                                                    AppColors.surface,
                                                title: const Text(
                                                    '¿Cuántas sesiones crear?'),
                                                content: TextField(
                                                    controller: ctrl,
                                                    keyboardType:
                                                        TextInputType.number),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              dCtx, null),
                                                      child: const Text(
                                                          'Cancelar')),
                                                  ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              dCtx,
                                                              int.tryParse(ctrl
                                                                  .text
                                                                  .trim())),
                                                      child:
                                                          const Text('Crear'))
                                                ],
                                              );
                                            });
                                        if (qty != null && qty > 0) {
                                          Navigator.pop(previewCtx);
                                          for (int i = 0; i < qty; i++) {
                                            await _generarSesion(m);
                                          }
                                        }
                                      },
                                      child: const Text('Crear varias'))),
                            ])
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final puntosTotales = _activas.fold<int>(0, (a, p) => a + p.puntos);
    final racha = _calcularRacha();

    return Scaffold(
      appBar: AppBar(title: const Text('Wolfia')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _saludo(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.bolt,
                    value: '${_activas.length}',
                    label: 'Activas',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    icon: Icons.stars_outlined,
                    value: '$puntosTotales',
                    label: 'Puntos',
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department_outlined,
                    value: '$racha',
                    label: racha == 1 ? 'Día seguido' : 'Días seguidos',
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_sesionEnCurso != null)
              _tarjetaContinuar()
            else
              _tarjetaGenerar(),
            const SizedBox(height: AppSpacing.lg),
            Text('Preparaciones activas',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (_activas.isEmpty)
              const _EmptyHint(
                texto: 'Todavía no tenés preparaciones activas.\n'
                    'Andá a la pestaña Repertorio para crear la primera.',
              )
            else
              ..._activas.map((p) => _tarjetaPreparacion(p)),
          ],
        ),
      ),
    );
  }

  /// Cuenta días consecutivos (hasta hoy) con al menos una sesión finalizada.
  int _calcularRacha() {
    final dias = _historial
        .where((s) => s.estado == 'finalizada')
        .map((s) => DateTime(s.fecha.year, s.fecha.month, s.fecha.day))
        .toSet();
    if (dias.isEmpty) return 0;

    var cursor = DateTime.now();
    var cursorSinHora = DateTime(cursor.year, cursor.month, cursor.day);
    if (!dias.contains(cursorSinHora)) {
      cursorSinHora = cursorSinHora.subtract(const Duration(days: 1));
      if (!dias.contains(cursorSinHora)) return 0;
    }
    int racha = 0;
    while (dias.contains(cursorSinHora)) {
      racha++;
      cursorSinHora = cursorSinHora.subtract(const Duration(days: 1));
    }
    return racha;
  }

  /// Saludo dinámico: ícono, color y mensaje según la hora del día,
  /// con la fecha de hoy debajo para que se sienta más "vivo".
  Widget _saludo() {
    final ahora = DateTime.now();
    final hora = ahora.hour;

    late final String saludo;
    late final IconData icono;
    late final Color color;
    if (hora < 6) {
      saludo = 'Buenas noches';
      icono = Icons.nights_stay_rounded;
      color = AppColors.info;
    } else if (hora < 12) {
      saludo = 'Buenos días';
      icono = Icons.wb_sunny_rounded;
      color = AppColors.warning;
    } else if (hora < 20) {
      saludo = 'Buenas tardes';
      icono = Icons.wb_twilight_rounded;
      color = AppColors.primary;
    } else {
      saludo = 'Buenas noches';
      icono = Icons.nights_stay_rounded;
      color = AppColors.info;
    }

    final fecha = DateFormat("EEEE d 'de' MMMM", 'es').format(ahora);
    final fechaCapitalizada = fecha[0].toUpperCase() + fecha.substring(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.18), AppColors.surface],
        ),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saludo,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fechaCapitalizada,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaContinuar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_circle_outline,
                  color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tenés una sesión en curso',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_sesionEnCurso!.duracionPlaneada} minutos planeados',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                      builder: (_) =>
                          SesionActivaScreen(sesionId: _sesionEnCurso!.id),
                    ))
                    .then((_) => _cargar());
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaGenerar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.auto_awesome, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Sesión de hoy',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Wolfia arma una propuesta de sesión según lo que hace '
              'más tiempo que no practicás y tus objetivos pendientes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _preguntarDuracion,
                child: const Text('Generar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFin(int minutos) {
    final ahora = DateTime.now();
    final fin = ahora.add(Duration(minutes: minutos));
    final hh = fin.hour.toString().padLeft(2, '0');
    final mm = fin.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _tarjetaPreparacion(Preparacion p) {
    final color = _estadoColor(p.estado);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_estadoIcon(p.estado), size: 12, color: color),
                            const SizedBox(width: 4),
                            Text(
                              p.estado,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color),
                            ),
                          ],
                        ),
                      ),
                      _PrioridadDots(p.prioridad),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_outlined,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    '${p.puntos}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Color semántico asociado a cada estado de preparación, igual que en
/// repertorio_screen.dart.
Color _estadoColor(String estado) {
  switch (estado) {
    case 'pendiente':
      return AppColors.textSecondary;
    case 'leyendo':
      return AppColors.info;
    case 'estudiando':
      return AppColors.primary;
    case 'consolidando':
      return AppColors.warning;
    case 'lista':
    case 'finalizada':
      return AppColors.success;
    default:
      return AppColors.textSecondary;
  }
}

IconData _estadoIcon(String estado) {
  switch (estado) {
    case 'pendiente':
      return Icons.schedule;
    case 'leyendo':
      return Icons.menu_book;
    case 'estudiando':
      return Icons.fitness_center;
    case 'consolidando':
      return Icons.tune;
    case 'lista':
      return Icons.check_circle_outline;
    case 'finalizada':
      return Icons.check_circle;
    default:
      return Icons.circle;
  }
}

/// Indicador visual de prioridad (1 a 5) con puntos coloreados, igual que
/// en repertorio_screen.dart.
class _PrioridadDots extends StatelessWidget {
  final int prioridad;
  const _PrioridadDots(this.prioridad);

  Color get _color {
    if (prioridad >= 4) return AppColors.warning;
    if (prioridad == 3) return AppColors.primary;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final lleno = i < prioridad;
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lleno ? color : AppColors.border,
            ),
          ),
        );
      }),
    );
  }
}

/// Tarjeta de resumen para el encabezado tipo dashboard, igual que en
/// repertorio_screen.dart y dominio_screen.dart.
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

class _EmptyHint extends StatelessWidget {
  final String texto;
  const _EmptyHint({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surface2),
      ),
      child:
          Text(texto, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}
