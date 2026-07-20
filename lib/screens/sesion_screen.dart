import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';

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
                child: Text(
                  'No hay ninguna sesión en curso.\n'
                  'Generá una desde la pestaña Inicio.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : SesionActivaScreen(sesionId: _sesion!.id, embebida: true),
    );
  }
}

/// Modo de estudio: pantalla enfocada, sin distracciones, con
/// temporizador por tarea y notas rápidas.
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
  bool _corriendo = false;
  bool _cargando = true;

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
      _segundosRestantes =
          tareas.isEmpty ? 0 : tareas[_indiceActual].minutosPlaneados * 60;
      _cargando = false;
    });
  }

  void _toggleTimer() {
    if (_corriendo) {
      _timer?.cancel();
      setState(() => _corriendo = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_segundosRestantes <= 0) {
          _timer?.cancel();
          setState(() => _corriendo = false);
          return;
        }
        setState(() => _segundosRestantes--);
      });
      setState(() => _corriendo = true);
    }
  }

  Future<void> _marcarResultado(String resultado) async {
    final tarea = _tareas[_indiceActual];
    tarea.completada = true;
    tarea.resultado = resultado;
    tarea.minutosReales =
        ((tarea.minutosPlaneados * 60 - _segundosRestantes) / 60).ceil();
    await _db.updateTarea(tarea);

    if (tarea.segmentoId != null) {
      // Actualizamos "última práctica" del segmento asociado si aplica.
      // (Simplificado: se podría extender guardando el segmento completo.)
    }

    if (_indiceActual < _tareas.length - 1) {
      setState(() {
        _indiceActual++;
        _segundosRestantes = _tareas[_indiceActual].minutosPlaneados * 60;
        _corriendo = false;
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
        title: const Text('Sesión finalizada 🎹'),
        content:
            Text('${sesion.duracionReal} minutos de estudio. ¡Buen trabajo!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _agregarNota() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
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
      return const Center(child: Text('Esta sesión no tiene tareas.'));
    }

    final tarea = _tareas[_indiceActual];
    final contenido = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            'Tarea ${_indiceActual + 1} de ${_tareas.length}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(tarea.tituloPreparacion,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          if (tarea.tituloSegmento != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tarea.tituloSegmento!,
                  style:
                      const TextStyle(color: AppColors.primary, fontSize: 18)),
            ),
          const SizedBox(height: AppSpacing.sm),
          if (tarea.motivo.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(tarea.motivo,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            _formatoTiempo(_segundosRestantes),
            style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w300,
                fontFamily: 'monospace'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                iconSize: 32,
                onPressed: _toggleTimer,
                icon: Icon(_corriendo ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                iconSize: 28,
                onPressed: _agregarNota,
                icon: const Icon(Icons.edit_note),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('¿Cómo salió?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              _botonResultado('😁', 'excelente'),
              _botonResultado('🙂', 'bien'),
              _botonResultado('😐', 'regular'),
              _botonResultado('🙁', 'difícil'),
            ],
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

  Widget _botonResultado(String emoji, String valor) {
    return ActionChip(
      label: Text('$emoji $valor'),
      onPressed: () => _marcarResultado(valor),
    );
  }
}
