import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import '../services/session_generator.dart';

/// Pestaña "Sesión": si hay una sesión en curso la muestra, si no invita
/// a generar una desde el Dashboard.
class SesionScreen extends StatefulWidget {
  const SesionScreen({super.key});

  @override
  State<SesionScreen> createState() => _SesionScreenState();
}

class _SesionScreenState extends State<SesionScreen> {
  final _db = WolfiaDb.instance;
  Sesion? _sesion;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final s = await _db.getSesionEnCurso();
    setState(() => _sesion = s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sesión')),
      body: _sesion == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 56,
                        color: AppColors.textSecondary.withOpacity(0.5)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No hay ninguna sesión en curso.\n'
                      'Generá una desde la pestaña Inicio.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          : SesionActivaScreen(sesionId: _sesion!.id, embebida: true),
    );
  }
}

/// Modo de estudio: pantalla enfocada, sin distracciones, con
/// temporizador circular estilo pomodoro y notas rápidas.
class SesionActivaScreen extends StatefulWidget {
  final String sesionId;
  final bool embebida; // true si va dentro de la pestaña (sin AppBar propia)
  const SesionActivaScreen(
      {super.key, required this.sesionId, this.embebida = false});

  @override
  State<SesionActivaScreen> createState() => _SesionActivaScreenState();
}

class _SesionActivaScreenState extends State<SesionActivaScreen> {
  final _db = WolfiaDb.instance;
  final _uuid = const Uuid();
  List<Tarea> _tareas = [];
  int _indiceActual = 0;
  Timer? _timer;
  int _segundosRestantes = 0;
  int _segundosTotales = 0;
  bool _corriendo = false;
  bool _cargando = true;

  // Se activa cuando la tarea termina (por tiempo o manualmente),
  // recién ahí aparece el bloque "¿Cómo salió?".
  bool _mostrarResultado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final tareas = await _db.getTareas(widget.sesionId);
    setState(() {
      _tareas = tareas;
      _indiceActual = tareas.indexWhere((t) => !t.completada);
      if (_indiceActual == -1) _indiceActual = 0;
      _segundosTotales =
          tareas.isEmpty ? 0 : tareas[_indiceActual].minutosPlaneados * 60;
      _segundosRestantes = _segundosTotales;
      _mostrarResultado = false;
      _cargando = false;
    });
  }

  void _toggleTimer() {
    if (_corriendo) {
      _timer?.cancel();
      setState(() => _corriendo = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_segundosRestantes <= 1) {
          _timer?.cancel();
          setState(() {
            _segundosRestantes = 0;
            _corriendo = false;
            _mostrarResultado = true; // se cumplió el tiempo -> pedir resultado
          });
          return;
        }
        setState(() => _segundosRestantes--);
      });
      setState(() => _corriendo = true);
    }
  }

  /// Permite cortar la tarea antes de que se acabe el tiempo y pasar
  /// directamente a calificar cómo salió.
  void _terminarAhora() {
    _timer?.cancel();
    setState(() {
      _corriendo = false;
      _mostrarResultado = true;
    });
  }

  Future<void> _marcarResultado(String resultado) async {
    final tarea = _tareas[_indiceActual];
    tarea.completada = true;
    tarea.resultado = resultado;
    tarea.minutosReales =
        ((tarea.minutosPlaneados * 60 - _segundosRestantes) / 60).ceil();
    await _db.updateTarea(tarea);

    if (tarea.objetivoId != null) {
      final objetivo = await _db.getObjetivoPorId(tarea.objetivoId!);
      if (objetivo != null) {
        objetivo.estadoMental = _mapaEstadoMental(resultado);
        await _db.updateObjetivo(objetivo);
      }
    }

    if (_indiceActual < _tareas.length - 1) {
      setState(() {
        _indiceActual++;
        _segundosTotales = _tareas[_indiceActual].minutosPlaneados * 60;
        _segundosRestantes = _segundosTotales;
        _corriendo = false;
        _mostrarResultado = false;
      });
      _timer?.cancel();
    } else {
      _finalizarSesion();
    }
  }

  Future<void> _finalizarSesion() async {
    _timer?.cancel();
    final todas = await _db.getTareas(widget.sesionId);
    final sesion = Sesion(
      id: widget.sesionId,
      fecha: DateTime.now(),
      duracionPlaneada: todas.fold(0, (a, t) => a + t.minutosPlaneados),
      duracionReal: todas.fold<int>(0, (a, t) => a + (t.minutosReales ?? 0)),
      estado: 'finalizada',
    );
    await _db.updateSesion(sesion);
    if (!mounted) return;
    if (!widget.embebida) Navigator.of(context).pop();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sesión finalizada 🎉'),
        content:
            Text('${sesion.duracionReal} minutos de estudio. ¡Buen trabajo!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  String _mapaEstadoMental(String resultado) {
    switch (resultado) {
      case 'excelente':
        return 'alto';
      case 'bien':
        return 'neutral';
      case 'regular':
        return 'bajo';
      case 'difícil':
        return 'bajo';
      default:
        return 'neutral';
    }
  }

  Future<void> _agregarNota() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nota rápida'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 3),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final tarea = _tareas[_indiceActual];
      await _db.insertNota(Nota(
        id: _uuid.v4(),
        contenido: ctrl.text.trim(),
        preparacionId: tarea.preparacionId,
        segmentoId: tarea.segmentoId,
        sesionId: widget.sesionId,
      ));
    }
  }

  String _formatoTiempo(int segundos) {
    final m = (segundos ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_tareas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Esta sesión no tiene tareas.'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                  onPressed: _verPlanSesion, child: const Text('Ver plan')),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                  onPressed: _generarTareasParaSesion,
                  child: const Text('Generar tareas para esta sesión')),
            ],
          ),
        ),
      );
    }

    final tarea = _tareas[_indiceActual];
    final progresoSesion =
        _tareas.isEmpty ? 0.0 : (_indiceActual) / _tareas.length;

    final contenido = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Progreso general de la sesión (barra fina arriba, discreta).
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progresoSesion.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tarea ${_indiceActual + 1} de ${_tareas.length}',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Tarjeta con la info de la tarea actual.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(tarea.tituloPreparacion,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
                if (tarea.tituloSegmento != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(tarea.tituloSegmento!,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  ),
                if (tarea.motivo.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(tarea.motivo,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Zona central: timer circular <-> bloque de resultado.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _mostrarResultado
                ? _bloqueResultado(context)
                : _bloqueTimer(context),
          ),
        ],
      ),
    );

    if (widget.embebida) return SingleChildScrollView(child: contenido);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo estudio'),
        actions: [
          TextButton(
              onPressed: _finalizarSesion, child: const Text('Finalizar')),
        ],
      ),
      body: SingleChildScrollView(child: contenido),
    );
  }

  /// Timer circular estilo pomodoro: el anillo se "vacía" a medida que
  /// pasa el tiempo.
  Widget _bloqueTimer(BuildContext context) {
    final progreso =
        _segundosTotales == 0 ? 0.0 : _segundosRestantes / _segundosTotales;

    return Column(
      key: const ValueKey('timer'),
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 240,
                height: 240,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 12,
                  color: AppColors.surface2,
                ),
              ),
              SizedBox(
                width: 240,
                height: 240,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 400),
                  tween: Tween(begin: progreso, end: progreso),
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatoTiempo(_segundosRestantes),
                    style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _corriendo ? 'En marcha' : 'En pausa',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 26,
              onPressed: _agregarNota,
              icon: const Icon(Icons.edit_note),
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.lg),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _toggleTimer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    _corriendo ? Icons.pause : Icons.play_arrow,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            IconButton(
              iconSize: 26,
              onPressed: _terminarAhora,
              icon: const Icon(Icons.check_circle_outline),
              color: AppColors.textSecondary,
              tooltip: 'Terminar tarea ahora',
            ),
          ],
        ),
      ],
    );
  }

  /// Bloque que pide calificar cómo salió: solo se muestra cuando la
  /// tarea terminó (por tiempo cumplido o de forma manual).
  Widget _bloqueResultado(BuildContext context) {
    return Column(
      key: const ValueKey('resultado'),
      children: [
        Icon(Icons.emoji_events_outlined, size: 44, color: AppColors.primary),
        const SizedBox(height: AppSpacing.sm),
        Text('¡Tiempo cumplido!',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('¿Cómo salió esta tarea?',
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            _botonResultado('😁', 'excelente'),
            _botonResultado('🙂', 'bien'),
            _botonResultado('😐', 'regular'),
            _botonResultado('🙁', 'difícil'),
          ],
        ),
      ],
    );
  }

  Future<void> _verPlanSesion() async {
    final ses = await (await _db.database)
        .query('sesiones', where: 'id = ?', whereArgs: [widget.sesionId]);
    if (ses.isEmpty) return;
    final dur = (ses.first['duracion_planeada'] as int?) ?? 0;
    final gen = SessionGenerator();
    final plan = await gen.planificar(minutosDisponibles: dur);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (ctx, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Plan de la sesión ($dur min)',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if ((plan['tareas'] as List).isEmpty)
              const Text('No hay tareas planificadas para este tiempo.'),
            ...((plan['tareas'] as List<Tarea>).map((t) => ListTile(
                  title: Text(t.tituloObjetivo ?? t.tituloPreparacion),
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

  Future<void> _generarTareasParaSesion() async {
    final sesRows = await (await _db.database)
        .query('sesiones', where: 'id = ?', whereArgs: [widget.sesionId]);
    if (sesRows.isEmpty) return;
    final dur = (sesRows.first['duracion_planeada'] as int?) ?? 0;
    final gen = SessionGenerator();
    final plan = await gen.planificar(minutosDisponibles: dur);
    final tareas = plan['tareas'] as List<Tarea>;
    for (final t in tareas) {
      final tareaAInsertar = Tarea(
        id: _uuid.v4(),
        sesionId: widget.sesionId,
        preparacionId: t.preparacionId,
        segmentoId: t.segmentoId,
        tituloPreparacion: t.tituloPreparacion,
        tituloSegmento: t.tituloSegmento,
        minutosPlaneados: t.minutosPlaneados,
        motivo: t.motivo,
      );
      await _db.insertTarea(tareaAInsertar);
    }
    await _cargar();
  }

  Widget _botonResultado(String emoji, String valor) {
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _marcarResultado(valor),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
