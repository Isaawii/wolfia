import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';

/// Color semántico por estado (preparación u objetivo cumplido/pendiente).
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
    case 'cumplido':
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
    case 'cumplido':
      return Icons.check_circle;
    default:
      return Icons.circle;
  }
}

String _formatFecha(DateTime d) {
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${d.day} ${meses[d.month - 1]} ${d.year}';
}

class PreparacionScreen extends StatefulWidget {
  final String preparacionId;
  const PreparacionScreen({super.key, required this.preparacionId});

  @override
  State<PreparacionScreen> createState() => _PreparacionScreenState();
}

class _PreparacionScreenState extends State<PreparacionScreen> {
  final _db = WolfiaDb.instance;
  final _uuid = const Uuid();
  Preparacion? _prep;
  Elemento? _elemento;
  List<Segmento> _segmentos = [];
  List<Objetivo> _objetivos = [];
  List<Categoria> _categorias = [];
  List<Profesor> _profesores = [];
  List<Nota> _notas = [];
  List<Problema> _problemas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todas = await _db.getTodasPreparaciones();
    final prep = todas.firstWhere((p) => p.id == widget.preparacionId);
    final elementos = await _db.getElementos();
    final elemento = elementos.firstWhere((e) => e.id == prep.elementoId);
    final segmentos = await _db.getSegmentos(widget.preparacionId);
    final objetivos = await _db.getObjetivos(widget.preparacionId);
    final categorias = await _db.getCategorias();
    final profesores = await _db.getProfesores();
    final notas = await _db.getNotasPorPreparacion(widget.preparacionId);
    final problemas = await _db.getProblemas();
    setState(() {
      _prep = prep;
      _elemento = elemento;
      _segmentos = segmentos;
      _objetivos = objetivos;
      _categorias = categorias;
      _profesores = profesores;
      _notas = notas;
      _problemas = problemas;
      _cargando = false;
    });
  }

  Future<void> _toggleActiva() async {
    _prep!.activa = !_prep!.activa;
    await _db.updatePreparacion(_prep!);
    _cargar();
  }

  Future<void> _editarPreparacion() async {
    final nombreCtrl = TextEditingController(text: _prep?.nombre ?? '');
    final objetivoCtrl =
        TextEditingController(text: _prep?.objetivoPrincipal ?? '');
    final categoriaCtrl = TextEditingController(text: _prep?.categoria ?? '');
    DateTime? fechaObj = _prep?.fechaObjetivo;
    int prioridad = _prep?.prioridad ?? 3;
    String? profesorId = _prep?.profesorId;
    final tempoActualCtrl =
        TextEditingController(text: _prep?.tempoActual?.toString() ?? '');
    final tempoObjetivoCtrl =
        TextEditingController(text: _prep?.tempoObjetivo?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Editar preparación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: objetivoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Objetivo principal',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue:
                      categoriaCtrl.text.isEmpty ? null : categoriaCtrl.text,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Ninguna')),
                    ..._categorias.map((c) => DropdownMenuItem(
                        value: c.nombre, child: Text(c.nombre)))
                  ],
                  onChanged: (v) => categoriaCtrl.text = v ?? '',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Text('Prioridad:'),
                    Expanded(
                      child: Slider(
                        value: prioridad.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$prioridad',
                        onChanged: (v) =>
                            setStateDialog(() => prioridad = v.round()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(fechaObj == null
                          ? 'Sin fecha límite'
                          : 'Límite: ${fechaObj!.toLocal().toString().split(' ').first}'),
                    ),
                    TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                              context: context,
                              initialDate: fechaObj ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100));
                          if (d != null) setStateDialog(() => fechaObj = d);
                        },
                        child: const Text('Seleccionar'))
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue: profesorId,
                  decoration: const InputDecoration(labelText: 'Profesor'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Ninguno')),
                    ..._profesores.map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.nombre)))
                  ],
                  onChanged: (v) => setStateDialog(() => profesorId = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: tempoActualCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Tempo actual (bpm)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: tempoObjetivoCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Tempo objetivo (bpm)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (ok == true && _prep != null && nombreCtrl.text.trim().isNotEmpty) {
      _prep!.nombre = nombreCtrl.text.trim();
      _prep!.objetivoPrincipal =
          objetivoCtrl.text.trim().isEmpty ? null : objetivoCtrl.text.trim();
      _prep!.categoria =
          categoriaCtrl.text.trim().isEmpty ? null : categoriaCtrl.text.trim();
      _prep!.fechaObjetivo = fechaObj;
      _prep!.prioridad = prioridad;
      _prep!.profesorId = profesorId;
      _prep!.tempoActual = int.tryParse(tempoActualCtrl.text.trim());
      _prep!.tempoObjetivo = int.tryParse(tempoObjetivoCtrl.text.trim());
      await _db.updatePreparacion(_prep!);
      _cargar();
    }
  }

  Future<void> _editarObjetivo(Objetivo o) async {
    final descCtrl = TextEditingController(text: o.descripcion);
    final puntosCtrl = TextEditingController(text: '${o.puntos}');
    final rateCtrl = TextEditingController(text: '${o.puntosPorMinuto}');
    final minCtrl = TextEditingController(text: '${o.tiempoMinimo}');
    final maxCtrl = TextEditingController(text: '${o.tiempoMaximo}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Editar objetivo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: puntosCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Puntos acumulados'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: rateCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Puntos por minuto'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: minCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Tiempo mínimo (min)')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: maxCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Tiempo máximo (min)')),
            ],
          ),
        ),
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

    if (ok == true) {
      o.descripcion = descCtrl.text.trim();
      o.puntos = int.tryParse(puntosCtrl.text.trim()) ?? o.puntos;
      o.puntosPorMinuto =
          int.tryParse(rateCtrl.text.trim()) ?? o.puntosPorMinuto;
      o.tiempoMinimo = int.tryParse(minCtrl.text.trim()) ?? o.tiempoMinimo;
      o.tiempoMaximo = int.tryParse(maxCtrl.text.trim()) ?? o.tiempoMaximo;
      await _db.updateObjetivo(o);
      _cargar();
    }
  }

  Future<void> _eliminarObjetivo(Objetivo o) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar objetivo'),
        content: const Text('¿Querés borrar este objetivo?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await (await _db.database)
          .delete('objetivos', where: 'id = ?', whereArgs: [o.id]);
      _cargar();
    }
  }

  Future<void> _addMinutesToObjetivo(Objetivo o) async {
    final minsCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Agregar minutos trabajados'),
        content: TextField(
          controller: minsCtrl,
          decoration: const InputDecoration(labelText: 'Minutos'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar')),
        ],
      ),
    );
    if (ok == true) {
      final mins = int.tryParse(minsCtrl.text.trim()) ?? 0;
      if (mins > 0) {
        o.puntos += mins * o.puntosPorMinuto;
        await _db.updateObjetivo(o);
        _cargar();
      }
    }
  }

  Future<void> _agregarONota() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nueva nota / link'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Texto o URL'),
            autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final n = Nota(
          id: _uuid.v4(),
          contenido: ctrl.text.trim(),
          preparacionId: widget.preparacionId);
      await _db.insertNota(n);
      _cargar();
    }
  }

  Future<void> _eliminarPreparacion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar preparación'),
        content: const Text(
            '¿Querés borrar esta preparación y todos sus segmentos/objetivos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deletePreparacion(widget.preparacionId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _agregarOEditarSegmento({Segmento? segmento}) async {
    final nombreCtrl = TextEditingController(text: segmento?.nombre ?? '');
    final inicioCtrl = TextEditingController(
        text:
            segmento?.compasInicio != null ? '${segmento!.compasInicio}' : '');
    final finCtrl = TextEditingController(
        text: segmento?.compasFin != null ? '${segmento!.compasFin}' : '');
    int prioridad = segmento?.prioridad ?? 3;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(segmento == null ? 'Nuevo segmento' : 'Editar segmento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nombre (ej: Compases 34-48)'),
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: inicioCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Desde compás',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: finCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hasta compás',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Text('Prioridad:'),
                    Expanded(
                      child: Slider(
                        value: prioridad.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$prioridad',
                        onChanged: (v) =>
                            setStateDialog(() => prioridad = v.round()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(segmento == null ? 'Crear' : 'Guardar')),
          ],
        ),
      ),
    );

    if (ok == true && nombreCtrl.text.trim().isNotEmpty) {
      final inicio = int.tryParse(inicioCtrl.text.trim());
      final fin = int.tryParse(finCtrl.text.trim());
      if (segmento == null) {
        final seg = Segmento(
          id: _uuid.v4(),
          preparacionId: widget.preparacionId,
          nombre: nombreCtrl.text.trim(),
          prioridad: prioridad,
          estado: 'activo',
          compasInicio: inicio,
          compasFin: fin,
        );
        await _db.insertSegmento(seg);
      } else {
        segmento.nombre = nombreCtrl.text.trim();
        segmento.prioridad = prioridad;
        segmento.compasInicio = inicio;
        segmento.compasFin = fin;
        await _db.updateSegmento(segmento);
      }
      _cargar();
    }
  }

  Widget _buildDiagrama() {
    if (_elemento == null ||
        _elemento!.compases == null ||
        _elemento!.compases! <= 0) {
      return const SizedBox.shrink();
    }
    final total = _elemento!.compases!;
    final visibles = _segmentos
        .where((s) =>
            s.compasInicio != null &&
            s.compasFin != null &&
            s.compasFin! > s.compasInicio!)
        .toList();
    if (visibles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Diagrama de compases',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  color: AppColors.bg.withValues(alpha: 0.1),
                ),
              ),
              ...visibles.map((s) {
                final start = (s.compasInicio! - 1).clamp(0, total).toDouble();
                final end = s.compasFin!.clamp(1, total).toDouble();
                final left = start / total;
                final width = ((end - start) / total).clamp(0.02, 1.0);
                return Positioned(
                  left: left * MediaQuery.of(context).size.width * 0.92,
                  top: 4,
                  bottom: 4,
                  width: width * MediaQuery.of(context).size.width * 0.92,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _colorForPrioridad(s.prioridad)
                          .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Total: $total compases',
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Color _colorForPrioridad(int prioridad) {
    switch (prioridad) {
      case 1:
        return AppColors.textSecondary;
      case 2:
        return AppColors.success;
      case 3:
        return AppColors.warning;
      case 4:
        return Color.lerp(AppColors.warning, AppColors.error, 0.6)!;
      case 5:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _agregarObjetivo() async {
    final descCtrl = TextEditingController();
    final puntosPorMinCtrl = TextEditingController(text: '1');
    final minCtrl = TextEditingController(text: '10');
    final maxCtrl = TextEditingController(text: '25');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nuevo objetivo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Ej: Negra = 108'),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: puntosPorMinCtrl,
                decoration: const InputDecoration(
                    labelText: 'Puntos por minuto (ej: 1)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: minCtrl,
                decoration:
                    const InputDecoration(labelText: 'Tiempo mínimo (min)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: maxCtrl,
                decoration:
                    const InputDecoration(labelText: 'Tiempo máximo (min)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear')),
        ],
      ),
    );

    if (ok == true && descCtrl.text.trim().isNotEmpty) {
      final rate = int.tryParse(puntosPorMinCtrl.text.trim()) ?? 1;
      final min = int.tryParse(minCtrl.text.trim()) ?? 10;
      final max = int.tryParse(maxCtrl.text.trim()) ?? 25;
      final obj = Objetivo(
        id: _uuid.v4(),
        preparacionId: widget.preparacionId,
        descripcion: descCtrl.text.trim(),
        puntos: 0,
        puntosPorMinuto: rate,
        tiempoMinimo: min,
        tiempoMaximo: max,
      );
      await _db.insertObjetivo(obj);
      _cargar();
    }
  }

  Future<void> _agregarObjetivoEnSegmento(Segmento s) async {
    final descCtrl = TextEditingController();
    final puntosPorMinCtrl = TextEditingController(text: '1');
    final minCtrl = TextEditingController(text: '10');
    final maxCtrl = TextEditingController(text: '25');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nuevo objetivo (segmento)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: puntosPorMinCtrl,
                decoration: const InputDecoration(
                    labelText: 'Puntos por minuto (ej: 1)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: minCtrl,
                decoration:
                    const InputDecoration(labelText: 'Tiempo mínimo (min)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: maxCtrl,
                decoration:
                    const InputDecoration(labelText: 'Tiempo máximo (min)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear')),
        ],
      ),
    );

    if (ok == true && descCtrl.text.trim().isNotEmpty) {
      final rate = int.tryParse(puntosPorMinCtrl.text.trim()) ?? 1;
      final min = int.tryParse(minCtrl.text.trim()) ?? 10;
      final max = int.tryParse(maxCtrl.text.trim()) ?? 25;
      final obj = Objetivo(
        id: _uuid.v4(),
        preparacionId: widget.preparacionId,
        segmentoId: s.id,
        descripcion: descCtrl.text.trim(),
        puntos: 0,
        puntosPorMinuto: rate,
        tiempoMinimo: min,
        tiempoMaximo: max,
      );
      await _db.insertObjetivo(obj);
      _cargar();
    }
  }

  Future<void> _asignarProblemaASegmento(Segmento s) async {
    final disponibles = _problemas.where((p) => p.segmentoId != s.id).toList();
    String? seleccionadoId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Asignar problema al segmento'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (disponibles.isEmpty)
                Column(
                  children: const [
                    Text('No hay problemas definidos. '),
                    SizedBox(height: AppSpacing.sm),
                    Text('Crea problemas desde la pestaña Dominio.')
                  ],
                )
              else
                DropdownButtonFormField<String>(
                  items: disponibles
                      .map((p) => DropdownMenuItem(
                          value: p.id, child: Text(p.descripcion)))
                      .toList(),
                  onChanged: (v) => seleccionadoId = v,
                  decoration: const InputDecoration(labelText: 'Problema'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Asignar')),
        ],
      ),
    );

    if (ok == true && seleccionadoId != null) {
      final p = _problemas.firstWhere((x) => x.id == seleccionadoId);
      p.segmentoId = s.id;
      p.preparacionId = widget.preparacionId;
      await _db.updateProblema(p);
      _cargar();
    }
  }

  Future<void> _toggleObjetivo(Objetivo o) async {
    o.estado = o.estado == 'cumplido' ? 'pendiente' : 'cumplido';
    await _db.updateObjetivo(o);
    _cargar();
  }

  // ---------------------------------------------------------------------
  // Construcción de cada pestaña (separado del build() para mayor claridad)
  // ---------------------------------------------------------------------

  Widget _buildGeneralTab(Preparacion prep) {
    final profesorNombre = _profesores
        .firstWhere((p) => p.id == prep.profesorId,
            orElse: () => Profesor(id: '', nombre: '—'))
        .nombre;
    final tempoTexto = (prep.tempoActual != null || prep.tempoObjetivo != null)
        ? '${prep.tempoActual ?? '—'} → ${prep.tempoObjetivo ?? '—'} bpm'
        : '—';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (prep.objetivoPrincipal != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'OBJETIVO PRINCIPAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  prep.objetivoPrincipal!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _EstadoChip(prep.estado),
            if (prep.categoria != null)
              _InfoChip(icon: Icons.calendar_view_week, label: prep.categoria!),
            _PrioridadDots(prep.prioridad),
            if (prep.fechaObjetivo != null) _DeadlineChip(prep.fechaObjetivo!),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 2.3,
          children: [
            _StatTile(
              icon: Icons.star_outline,
              label: 'Puntos acumulados',
              value: '${prep.puntos}',
            ),
            _StatTile(
              icon: Icons.timer_outlined,
              label: 'Tiempo invertido',
              value: '${prep.tiempoInvertido} min',
            ),
            _StatTile(
              icon: Icons.event_repeat,
              label: 'Sesiones',
              value: '${prep.sesionesCount}',
            ),
            _StatTile(
              icon: Icons.speed,
              label: 'Tempo actual → objetivo',
              value: tempoTexto,
            ),
            _StatTile(
              icon: Icons.calendar_today_outlined,
              label: 'Fecha inicio',
              value: _formatFecha(prep.creadoEn),
            ),
            _StatTile(
              icon: Icons.person_outline,
              label: 'Profesor',
              value: profesorNombre,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentosTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SectionHeader(
          icon: Icons.view_agenda_outlined,
          titulo: 'Segmentos',
          onAdd: () => _agregarOEditarSegmento(),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_elemento != null && _elemento!.compases != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _buildDiagrama(),
          ),
        ..._segmentos.map((s) {
          final objetivosDelSegmento =
              _objetivos.where((o) => o.segmentoId == s.id);
          return Card(
            child: ExpansionTile(
              title: Text(s.nombre),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _PrioridadDots(s.prioridad),
                    _RecenciaChip(dias: s.diasSinPracticar()),
                    if (s.compasInicio != null || s.compasFin != null)
                      _InfoChip(
                        icon: Icons.straighten,
                        label: '${s.compasInicio ?? '?'}-${s.compasFin ?? '?'}',
                      ),
                    if (s.tempoActual != null || s.tempoObjetivo != null)
                      _InfoChip(
                        icon: Icons.speed,
                        label:
                            '${s.tempoActual ?? '—'} → ${s.tempoObjetivo ?? '—'} bpm',
                      ),
                  ],
                ),
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'editar') {
                    await _agregarOEditarSegmento(segmento: s);
                  } else if (value == 'eliminar') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Eliminar segmento'),
                        content: const Text('¿Querés borrar este segmento?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Eliminar')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _db.deleteSegmento(s.id);
                      _cargar();
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ),
              children: [
                if (objetivosDelSegmento.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Text('Sin objetivos en este segmento',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ...objetivosDelSegmento.map((o) => _ObjetivoTile(
                        objetivo: o,
                        onToggle: () => _toggleObjetivo(o),
                        onEditar: () => _editarObjetivo(o),
                        onMinutos: () => _addMinutesToObjetivo(o),
                        onEliminar: () => _eliminarObjetivo(o),
                      )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => _agregarObjetivoEnSegmento(s),
                        child: const Text('Agregar objetivo')),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                        onPressed: () => _asignarProblemaASegmento(s),
                        child: const Text('Asignar problema')),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Builder(builder: (ctx) {
                  final problemasDelSegmento =
                      _problemas.where((p) => p.segmentoId == s.id);
                  if (problemasDelSegmento.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Text('Problemas asociados',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ...problemasDelSegmento.map((p) => Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: AppSpacing.md),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.descripcion,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _InfoChip(
                                            icon: Icons.warning_amber,
                                            label: 'Intensidad ${p.intensidad}',
                                            color: AppColors.warning,
                                          ),
                                          _InfoChip(
                                            icon: Icons.info_outline,
                                            label: p.estado,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (v) async {
                                    if (v == 'desasignar') {
                                      p.segmentoId = null;
                                      await _db.updateProblema(p);
                                      _cargar();
                                    } else if (v == 'editar') {
                                      Navigator.pushNamed(context, '/dominio');
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'editar',
                                        child: Text('Editar en Dominio')),
                                    PopupMenuItem(
                                        value: 'desasignar',
                                        child: Text('Desasignar')),
                                  ],
                                ),
                              ],
                            ),
                          )),
                    ],
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildObjetivosTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SectionHeader(
          icon: Icons.flag_outlined,
          titulo: 'Objetivos',
          onAdd: _agregarObjetivo,
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._objetivos.map((o) => _ObjetivoTile(
              objetivo: o,
              onToggle: () => _toggleObjetivo(o),
              onEditar: () => _editarObjetivo(o),
              onMinutos: () => _addMinutesToObjetivo(o),
              onEliminar: () => _eliminarObjetivo(o),
            )),
      ],
    );
  }

  Widget _buildMaterialTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SectionHeader(
          icon: Icons.sticky_note_2_outlined,
          titulo: 'Material y notas',
          onAdd: _agregarONota,
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._notas.map((n) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.contenido,
                            style: const TextStyle(color: AppColors.text)),
                        const SizedBox(height: 4),
                        Text(
                          _formatFecha(n.fecha),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) async {
                      if (v == 'eliminar') {
                        final c = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: const Text('Eliminar nota'),
                                  content:
                                      const Text('¿Querés borrar esta nota?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar')),
                                    ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Eliminar'))
                                  ],
                                ));
                        if (c == true) {
                          await (await _db.database).delete('notas',
                              where: 'id = ?', whereArgs: [n.id]);
                          _cargar();
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'eliminar', child: Text('Eliminar'))
                    ],
                  ),
                ],
              ),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final prep = _prep!;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(prep.nombre),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: _ActivaToggle(activa: prep.activa, onTap: _toggleActiva),
            ),
            IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Editar preparación',
                onPressed: _editarPreparacion),
            IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar preparación',
                onPressed: _eliminarPreparacion),
          ],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'General'),
            Tab(icon: Icon(Icons.view_agenda_outlined), text: 'Segmentos'),
            Tab(icon: Icon(Icons.flag_outlined), text: 'Objetivos'),
            Tab(icon: Icon(Icons.sticky_note_2_outlined), text: 'Material'),
          ]),
        ),
        body: TabBarView(children: [
          _buildGeneralTab(prep),
          _buildSegmentosTab(),
          _buildObjetivosTab(),
          _buildMaterialTab(),
        ]),
      ),
    );
  }
}

/// Pill tappable que reemplaza el antiguo ícono play/pause: dice
/// explícitamente "Activa" o "Pausada" y se puede tocar para alternar.
class _ActivaToggle extends StatelessWidget {
  final bool activa;
  final VoidCallback onTap;
  const _ActivaToggle({required this.activa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = activa ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              activa ? 'Activa' : 'Pausada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado de sección reutilizable: ícono + título + botón de agregar.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final VoidCallback onAdd;
  const _SectionHeader({
    required this.icon,
    required this.titulo,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.primary,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

/// Tarjeta chica de estadística para la grilla de la pestaña General.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge de estado con ícono y color semántico (preparación u objetivo).
class _EstadoChip extends StatelessWidget {
  final String estado;
  const _EstadoChip(this.estado);

  @override
  Widget build(BuildContext context) {
    final color = _estadoColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_estadoIcon(estado), size: 12, color: color),
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

/// Chip genérico neutro para mostrar un dato con ícono (categoría, tempo, etc).
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Indicador de prioridad (1 a 5) con puntitos.
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

/// Chip de fecha límite, coloreado según urgencia.
class _DeadlineChip extends StatelessWidget {
  final DateTime fecha;
  const _DeadlineChip(this.fecha);

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final dias = fecha.difference(hoySinHora).inDays;

    Color color;
    String texto;
    if (dias < 0) {
      color = AppColors.error;
      texto = 'Vencida';
    } else if (dias == 0) {
      color = AppColors.error;
      texto = 'Hoy';
    } else if (dias <= 7) {
      color = AppColors.warning;
      texto = 'En $dias d';
    } else {
      color = AppColors.textSecondary;
      texto = _formatFecha(fecha);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event, size: 12, color: color),
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

/// Chip de recencia ("hace N días" / "sin practicar"), coloreado según
/// cuánto hace que no se practica ese segmento.
class _RecenciaChip extends StatelessWidget {
  final int dias;
  const _RecenciaChip({required this.dias});

  @override
  Widget build(BuildContext context) {
    Color color;
    String texto;
    if (dias >= 999) {
      color = AppColors.error;
      texto = 'Sin practicar';
    } else if (dias == 0) {
      color = AppColors.success;
      texto = 'Hoy';
    } else if (dias <= 3) {
      color = AppColors.success;
      texto = 'Hace $dias d';
    } else if (dias <= 14) {
      color = AppColors.warning;
      texto = 'Hace $dias d';
    } else {
      color = AppColors.error;
      texto = 'Hace $dias d';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 12, color: color),
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

/// Fila de objetivo reutilizada tanto dentro de un segmento como en la
/// pestaña general de Objetivos, para que ambos luzcan consistentes.
class _ObjetivoTile extends StatelessWidget {
  final Objetivo objetivo;
  final VoidCallback onToggle;
  final VoidCallback onEditar;
  final VoidCallback onMinutos;
  final VoidCallback onEliminar;

  const _ObjetivoTile({
    required this.objetivo,
    required this.onToggle,
    required this.onEditar,
    required this.onMinutos,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final o = objetivo;
    final cumplido = o.estado == 'cumplido';
    return Container(
      margin:
          const EdgeInsets.symmetric(vertical: 4, horizontal: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: cumplido,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.success,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.descripcion,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    decoration: cumplido ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _InfoChip(
                        icon: Icons.star_outline, label: '${o.puntos} pts'),
                    _InfoChip(
                        icon: Icons.speed, label: '${o.puntosPorMinuto}/min'),
                    _InfoChip(
                      icon: Icons.timer_outlined,
                      label: '${o.tiempoMinimo}-${o.tiempoMaximo} min',
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (v) {
              if (v == 'editar') onEditar();
              if (v == 'minutos') onMinutos();
              if (v == 'eliminar') onEliminar();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'editar', child: Text('Editar')),
              PopupMenuItem(value: 'minutos', child: Text('Agregar minutos')),
              PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}
