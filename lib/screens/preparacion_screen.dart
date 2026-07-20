import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';

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
                    labelText: 'Objetivo principal (opcional)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue:
                      categoriaCtrl.text.isEmpty ? null : categoriaCtrl.text,
                  decoration:
                      const InputDecoration(labelText: 'Categoría (opcional)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('— ninguna —')),
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
                  decoration:
                      const InputDecoration(labelText: 'Profesor (opcional)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('— ninguno —')),
                    ..._profesores.map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.nombre)))
                  ],
                  onChanged: (v) => setStateDialog(() => profesorId = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: tempoActualCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tempo actual (bpm) (opcional)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: tempoObjetivoCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tempo objetivo (bpm) (opcional)'),
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
        return Colors.blueGrey;
      case 2:
        return AppColors.success;
      case 3:
        return AppColors.warning;
      case 4:
        return Colors.deepOrange;
      case 5:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _agregarObjetivo() async {
    final descCtrl = TextEditingController();
    final puntosPorMinCtrl = TextEditingController(text: '1');
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
      final obj = Objetivo(
        id: _uuid.v4(),
        preparacionId: widget.preparacionId,
        descripcion: descCtrl.text.trim(),
        puntos: 0,
        puntosPorMinuto: rate,
      );
      await _db.insertObjetivo(obj);
      _cargar();
    }
  }

  Future<void> _agregarObjetivoEnSegmento(Segmento s) async {
    final descCtrl = TextEditingController();
    final puntosPorMinCtrl = TextEditingController(text: '1');
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
      final obj = Objetivo(
        id: _uuid.v4(),
        preparacionId: widget.preparacionId,
        segmentoId: s.id,
        descripcion: descCtrl.text.trim(),
        puntos: 0,
        puntosPorMinuto: rate,
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
            IconButton(
              icon: Icon(prep.activa ? Icons.pause : Icons.play_arrow),
              tooltip: prep.activa ? 'Archivar' : 'Activar',
              onPressed: _toggleActiva,
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
            Tab(text: 'General'),
            Tab(text: 'Segmentos'),
            Tab(text: 'Objetivos'),
            Tab(text: 'Material')
          ]),
        ),
        body: TabBarView(children: [
          // General tab
          ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
            if (prep.objetivoPrincipal != null) ...[
              Text('Objetivo principal',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(prep.objetivoPrincipal!,
                  style: const TextStyle(color: AppColors.primary)),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text('Estado: ${prep.estado}'),
            const SizedBox(height: AppSpacing.sm),
            Text(
                'Fecha inicio: ${prep.creadoEn.toLocal().toString().split(' ').first}'),
            const SizedBox(height: AppSpacing.sm),
            Text(
                'Fecha límite: ${prep.fechaObjetivo != null ? prep.fechaObjetivo!.toLocal().toString().split(' ').first : '—'}'),
            const SizedBox(height: AppSpacing.sm),
            Text('Prioridad: ${prep.prioridad}/5'),
            const SizedBox(height: AppSpacing.sm),
            Text('Puntos acumulados: ${prep.puntos}'),
            const SizedBox(height: AppSpacing.sm),
            Text('Tiempo invertido: ${prep.tiempoInvertido} min'),
            const SizedBox(height: AppSpacing.sm),
            Text('Tempo actual: ${prep.tempoActual ?? '—'}'),
            const SizedBox(height: AppSpacing.sm),
            Text('Tempo objetivo: ${prep.tempoObjetivo ?? '—'}'),
            const SizedBox(height: AppSpacing.sm),
            Text('Sesiones involucradas: ${prep.sesionesCount}'),
            const SizedBox(height: AppSpacing.sm),
            Text('Categoría: ${prep.categoria ?? '—'}'),
            const SizedBox(height: AppSpacing.sm),
            Text(
                'Profesor: ${_profesores.firstWhere((p) => p.id == prep.profesorId, orElse: () => Profesor(id: '', nombre: '—')).nombre}'),
          ]),
          // Segmentos tab
          ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Segmentos', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _agregarOEditarSegmento())
            ]),
            if (_elemento != null && _elemento!.compases != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: _buildDiagrama()),
            ..._segmentos.map((s) {
              final objetivosDelSegmento =
                  _objetivos.where((o) => o.segmentoId == s.id).toList();
              return Card(
                child: ExpansionTile(
                  title: Text(s.nombre),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Prioridad ${s.prioridad}/5 · ${s.diasSinPracticar() >= 999 ? 'sin practicar' : 'hace ${s.diasSinPracticar()} días'}'),
                      if (s.compasInicio != null || s.compasFin != null)
                        Text(
                            'Compases: ${s.compasInicio ?? '?'} - ${s.compasFin ?? '?'}'),
                      if (s.tempoActual != null || s.tempoObjetivo != null)
                        Text(
                            'Tempo: actual ${s.tempoActual ?? '—'} · objetivo ${s.tempoObjetivo ?? '—'}'),
                    ],
                  ),
                  children: [
                    if (objetivosDelSegmento.isEmpty)
                      const ListTile(
                          title: Text('Sin objetivos en este segmento'))
                    else
                      ...objetivosDelSegmento.map((o) => ListTile(
                            leading: Checkbox(
                                value: o.estado == 'cumplido',
                                onChanged: (_) => _toggleObjetivo(o)),
                            title: Text(o.descripcion),
                            subtitle: Text(
                                'Puntos: ${o.puntos} · ${o.puntosPorMinuto}/min'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'editar') await _editarObjetivo(o);
                                if (v == 'minutos')
                                  await _addMinutesToObjetivo(o);
                                if (v == 'eliminar') await _eliminarObjetivo(o);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'editar', child: Text('Editar')),
                                PopupMenuItem(
                                    value: 'minutos',
                                    child: Text('Agregar minutos')),
                                PopupMenuItem(
                                    value: 'eliminar', child: Text('Eliminar')),
                              ],
                            ),
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
                      final problemasDelSegmento = _problemas
                          .where((p) => p.segmentoId == s.id)
                          .toList();
                      if (problemasDelSegmento.isEmpty)
                        return const SizedBox.shrink();
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
                          ...problemasDelSegmento.map((p) => ListTile(
                                title: Text(p.descripcion),
                                subtitle: Text(
                                    'Intensidad: ${p.intensidad} · Estado: ${p.estado}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'desasignar') {
                                      p.segmentoId = null;
                                      await _db.updateProblema(p);
                                      _cargar();
                                    } else if (v == 'editar') {
                                      // open dominio edit flow
                                      // For simplicity reuse Dominio screen flow: open dominio to edit
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
                              ))
                        ],
                      );
                    })
                  ],
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
                            content:
                                const Text('¿Querés borrar este segmento?'),
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
                ),
              );
            }),
          ]),
          // Objetivos tab
          ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Objetivos', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                  icon: const Icon(Icons.add), onPressed: _agregarObjetivo)
            ]),
            ..._objetivos.map((o) => Card(
                    child: CheckboxListTile(
                  value: o.estado == 'cumplido',
                  onChanged: (_) => _toggleObjetivo(o),
                  title: Text(o.descripcion,
                      style: TextStyle(
                          decoration: o.estado == 'cumplido'
                              ? TextDecoration.lineThrough
                              : null)),
                  subtitle:
                      Text('Puntos: ${o.puntos} · ${o.puntosPorMinuto}/min'),
                  activeColor: AppColors.primary,
                  secondary: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      if (v == 'editar') {
                        await _editarObjetivo(o);
                      } else if (v == 'minutos') {
                        await _addMinutesToObjetivo(o);
                      } else if (v == 'eliminar') {
                        await _eliminarObjetivo(o);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(
                          value: 'minutos', child: Text('Agregar minutos')),
                      PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                    ],
                  ),
                ))),
          ]),
          // Material / Notas tab
          ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Material y notas',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(icon: const Icon(Icons.add), onPressed: _agregarONota)
            ]),
            const SizedBox(height: AppSpacing.sm),
            ..._notas.map((n) => Card(
                    child: ListTile(
                  title: Text(n.contenido),
                  subtitle: Text(n.fecha.toLocal().toString()),
                  trailing: PopupMenuButton<String>(
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
                ))),
          ]),
        ]),
      ),
    );
  }
}
