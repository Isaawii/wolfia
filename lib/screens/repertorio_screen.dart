import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'preparacion_screen.dart';

//Para la creación de categorías
const _diasSemana = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];
//Para detalles de la obra/ejercicio
const _tonalidades = [
  'Do mayor',
  'Do menor',
  'Do# mayor',
  'Do# menor',
  'Re mayor',
  'Re menor',
  'Mib mayor',
  'Mib menor',
  'Mi mayor',
  'Mi menor',
  'Fa mayor',
  'Fa menor',
  'Fa# mayor',
  'Fa# menor',
  'Sol mayor',
  'Sol menor',
  'Lab mayor',
  'Sol# menor',
  'La mayor',
  'La menor',
  'Sib mayor',
  'Sib menor',
  'Si mayor',
  'Si menor',
];
const _estadosPreparacion = [
  'pendiente',
  'leyendo',
  'estudiando',
  'consolidando',
  'lista',
  'finalizada'
];

/// Color semántico asociado a cada estado de preparación.
/// Se reutiliza tanto en los badges de la lista como en el selector
/// del diálogo de edición, para que el lenguaje visual sea consistente.
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

String _formatFechaCorta(DateTime d) {
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
  return '${d.day} ${meses[d.month - 1]}';
}

class RepertorioScreen extends StatefulWidget {
  final String tipo;
  const RepertorioScreen({super.key, this.tipo = 'obra'});

  @override
  State<RepertorioScreen> createState() => _RepertorioScreenState();
}

class _RepertorioScreenState extends State<RepertorioScreen> {
  final _db = WolfiaDb.instance;
  final _uuid = const Uuid();
  List<Elemento> _elementos = [];
  List<Categoria> _categorias = [];
  List<Profesor> _profesores = [];
  Map<String, List<Preparacion>> _preparacionesPorElemento = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final elementos = await _db.getElementos();
    final todasPreps = await _db.getTodasPreparaciones();
    final categorias = await _db.getCategorias();
    final profesores = await _db.getProfesores();
    final mapa = <String, List<Preparacion>>{};
    for (final p in todasPreps) {
      mapa.putIfAbsent(p.elementoId, () => []).add(p);
    }
    setState(() {
      _elementos = elementos;
      _categorias = categorias;
      _profesores = profesores;
      _preparacionesPorElemento = mapa;
      _cargando = false;
    });
  }

  /// Alterna el estado activo/pausado de una preparación directamente
  /// desde la lista, sin pasar por el diálogo de edición.
  Future<void> _toggleActiva(Preparacion p, bool value) async {
    p.activa = value;
    await _db.updatePreparacion(p);
    _cargar();
  }

  /// Fecha límite más cercana entre las preparaciones de los elementos dados.
  /// Prioriza fechas futuras; si todas ya vencieron, devuelve la más próxima.
  DateTime? _proximaFechaLimite(List<Elemento> elementos) {
    final fechas = <DateTime>[];
    for (final e in elementos) {
      final preps = _preparacionesPorElemento[e.id] ?? [];
      for (final p in preps) {
        if (p.fechaObjetivo != null) fechas.add(p.fechaObjetivo!);
      }
    }
    if (fechas.isEmpty) return null;
    fechas.sort();
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final futuras = fechas.where((f) => !f.isBefore(hoySinHora));
    return futuras.isNotEmpty ? futuras.first : fechas.first;
  }

//Crear o editar elemento de estudio (obra o ejercicio)
  Future<void> _crearOEditarElemento({Elemento? existente}) async {
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final compositorCtrl =
        TextEditingController(text: existente?.compositor ?? '');
    final compasesCtrl = TextEditingController(
      text: existente?.compases != null ? '${existente!.compases}' : '',
    );
    final tempoCtrl = TextEditingController(text: existente?.tempo ?? '');
    final duracionCtrl = TextEditingController(
      text:
          existente?.duracionAprox != null ? '${existente!.duracionAprox}' : '',
    );
    final anioCtrl = TextEditingController(
      text: existente?.anio != null ? '${existente!.anio}' : '',
    );
    String? tonalidad = existente?.tonalidad;
    int prioridad = existente?.prioridad ?? 3;
    final tipo = existente?.tipo ?? widget.tipo;
    bool masDatos = existente != null &&
        (existente.tonalidad != null ||
            existente.tempo != null ||
            existente.duracionAprox != null ||
            existente.anio != null);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(existente == null
              ? (tipo == 'obra' ? 'Nueva obra' : 'Nuevo ejercicio')
              : (tipo == 'obra' ? 'Editar obra' : 'Editar ejercicio')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (tipo == 'obra')
                  TextField(
                    controller: compositorCtrl,
                    decoration: const InputDecoration(labelText: 'Compositor'),
                  ),
                if (tipo == 'obra') const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: compasesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Compases totales'),
                  keyboardType: TextInputType.number,
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
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            setStateDialog(() => prioridad = v.round()),
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                InkWell(
                  onTap: () => setStateDialog(() => masDatos = !masDatos),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Icon(masDatos ? Icons.expand_less : Icons.expand_more,
                            color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        const Text('Completar más datos'),
                      ],
                    ),
                  ),
                ),
                if (masDatos) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String?>(
                    initialValue: tonalidad,
                    decoration: const InputDecoration(labelText: 'Tonalidad'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Sin especificar')),
                      ..._tonalidades.map(
                          (t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (v) => setStateDialog(() => tonalidad = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: tempoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tempo',
                      hintText: 'Ej: Negra = 120, o 3+2+3/8 = 96',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: duracionCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Duración aproximada (min)'),
                    keyboardType: TextInputType.number,
                  ),
                  if (tipo == 'obra') ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: anioCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Año de la pieza'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existente == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result != true || nombreCtrl.text.trim().isEmpty) return;

    final compases = int.tryParse(compasesCtrl.text.trim());
    final duracion = int.tryParse(duracionCtrl.text.trim());
    final anio = tipo == 'obra' ? int.tryParse(anioCtrl.text.trim()) : null;

    if (existente == null) {
      final elemento = Elemento(
        id: _uuid.v4(),
        nombre: nombreCtrl.text.trim(),
        tipo: tipo,
        compositor: compositorCtrl.text.trim().isEmpty
            ? null
            : compositorCtrl.text.trim(),
        compases: compases,
        prioridad: prioridad,
        tonalidad: tonalidad,
        tempo: tempoCtrl.text.trim().isEmpty ? null : tempoCtrl.text.trim(),
        duracionAprox: duracion,
        anio: anio,
      );
      await _db.insertElemento(elemento);
    } else {
      existente.nombre = nombreCtrl.text.trim();
      existente.tipo = tipo;
      existente.compositor = compositorCtrl.text.trim().isEmpty
          ? null
          : compositorCtrl.text.trim();
      existente.compases = compases;
      existente.prioridad = prioridad;
      existente.tonalidad = tonalidad;
      existente.tempo =
          tempoCtrl.text.trim().isEmpty ? null : tempoCtrl.text.trim();
      existente.duracionAprox = duracion;
      existente.anio = anio;
      await _db.updateElemento(existente);
    }

    _cargar();
  }

  Future<String?> _crearProfesorRapido() async {
    final nombreCtrl = TextEditingController();
    final contactoCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nuevo profesor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: contactoCtrl,
              decoration: const InputDecoration(labelText: 'Contacto'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result != true || nombreCtrl.text.trim().isEmpty) return null;

    final nuevoProfesor = Profesor(
      id: _uuid.v4(),
      nombre: nombreCtrl.text.trim(),
      contacto:
          contactoCtrl.text.trim().isEmpty ? null : contactoCtrl.text.trim(),
    );
    await _db.insertProfesor(nuevoProfesor);
    return nuevoProfesor.id;
  }

  Future<String?> _crearCategoriaRapida() async {
    final nombreCtrl = TextEditingController();
    final minutosCtrl = TextEditingController(text: '60');
    final diasSeleccionados = Set<String>.from(_diasSemana);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Nueva categoría'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: minutosCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Minutos objetivo por semana'),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Días de la semana',
                    style: TextStyle(color: AppColors.textSecondary)),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: _diasSemana.map((d) {
                    final activo = diasSeleccionados.contains(d);
                    return FilterChip(
                      label: Text(d),
                      selected: activo,
                      onSelected: (v) => setStateDialog(() {
                        if (v) {
                          diasSeleccionados.add(d);
                        } else {
                          diasSeleccionados.remove(d);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (result != true || nombreCtrl.text.trim().isEmpty) return null;

    final diasOrdenados =
        _diasSemana.where((d) => diasSeleccionados.contains(d)).join(',');
    final minutos = int.tryParse(minutosCtrl.text.trim()) ?? 0;

    final nuevaCategoria = Categoria(
      id: _uuid.v4(),
      nombre: nombreCtrl.text.trim(),
      diasSemana: diasOrdenados,
      minutosObjetivo: minutos,
    );
    await _db.insertCategoria(nuevaCategoria);
    return nuevaCategoria.nombre;
  }

//Las obras/ejercicios se pueden dividir en preparaciones. Cada preparación usa la misma obra/ejercicio, pero con finalidades diferentes
  Future<void> _crearOEditarPreparacion(Elemento elemento,
      {Preparacion? existente}) async {
    final nombreCtrl =
        TextEditingController(text: existente?.nombre ?? 'Preparación');
    final objetivoCtrl =
        TextEditingController(text: existente?.objetivoPrincipal ?? '');
    final categoriaCtrl =
        TextEditingController(text: existente?.categoria ?? '');
    DateTime? fechaObjetivo = existente?.fechaObjetivo;
    int prioridad = existente?.prioridad ?? 3;
    String estado = existente?.estado ?? 'pendiente';
    String? profesorId = existente?.profesorId;
    final tempoActualCtrl =
        TextEditingController(text: existente?.tempoActual?.toString() ?? '');
    final tempoObjetivoCtrl =
        TextEditingController(text: existente?.tempoObjetivo?.toString() ?? '');
    bool masDatos = existente != null &&
        (existente.profesorId != null ||
            existente.tempoActual != null ||
            existente.tempoObjetivo != null);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(existente == null
              ? 'Nueva preparación · ${elemento.nombre}'
              : 'Editar preparación · ${elemento.nombre}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: objetivoCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Objetivo principal'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue:
                      categoriaCtrl.text.isEmpty ? null : categoriaCtrl.text,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Ninguna')),
                    ..._categorias.map((c) => DropdownMenuItem(
                          value: c.nombre,
                          child: Text(c.nombre),
                        )),
                  ],
                  onChanged: (value) => categoriaCtrl.text = value ?? '',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final nombre = await _crearCategoriaRapida();
                      if (nombre != null) {
                        categoriaCtrl.text = nombre;
                        _cargar();
                      }
                    },
                    child: const Text('Nueva categoría'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: estado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: _estadosPreparacion.map((e) {
                    return DropdownMenuItem(
                      value: e,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_estadoIcon(e),
                              size: 16, color: _estadoColor(e)),
                          const SizedBox(width: AppSpacing.xs),
                          Text(e),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setStateDialog(() => estado = v!),
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
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            setStateDialog(() => prioridad = v.round()),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(fechaObjetivo == null
                          ? 'Sin fecha límite'
                          : 'Límite: ${fechaObjetivo!.toLocal().toString().split(' ').first}'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: fechaObjetivo ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setStateDialog(() => fechaObjetivo = d);
                      },
                      child: const Text('Seleccionar'),
                    ),
                    if (fechaObjetivo != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Quitar fecha',
                        onPressed: () =>
                            setStateDialog(() => fechaObjetivo = null),
                      ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                InkWell(
                  onTap: () => setStateDialog(() => masDatos = !masDatos),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Icon(masDatos ? Icons.expand_less : Icons.expand_more,
                            color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        const Text('Completar más datos'),
                      ],
                    ),
                  ),
                ),
                if (masDatos) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String?>(
                    initialValue: profesorId,
                    decoration: const InputDecoration(labelText: 'Profesor'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Ninguno')),
                      ..._profesores.map((p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.nombre))),
                    ],
                    onChanged: (v) => setStateDialog(() => profesorId = v),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        final id = await _crearProfesorRapido();
                        if (id != null) {
                          await _cargar();
                          setStateDialog(() => profesorId = id);
                        }
                      },
                      child: const Text('Nuevo profesor'),
                    ),
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
                    decoration: const InputDecoration(
                        labelText: 'Tempo objetivo (bpm)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existente == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result != true || nombreCtrl.text.trim().isEmpty) return;

    final tempoActual = int.tryParse(tempoActualCtrl.text.trim());
    final tempoObjetivo = int.tryParse(tempoObjetivoCtrl.text.trim());

    if (existente == null) {
      final prep = Preparacion(
        id: _uuid.v4(),
        elementoId: elemento.id,
        nombre: nombreCtrl.text.trim(),
        objetivoPrincipal:
            objetivoCtrl.text.trim().isEmpty ? null : objetivoCtrl.text.trim(),
        categoria: categoriaCtrl.text.trim().isEmpty
            ? null
            : categoriaCtrl.text.trim(),
        estado: estado,
        prioridad: prioridad,
        fechaObjetivo: fechaObjetivo,
        profesorId: profesorId,
        tempoActual: tempoActual,
        tempoObjetivo: tempoObjetivo,
      );
      await _db.insertPreparacion(prep);
    } else {
      existente.nombre = nombreCtrl.text.trim();
      existente.objetivoPrincipal =
          objetivoCtrl.text.trim().isEmpty ? null : objetivoCtrl.text.trim();
      existente.categoria =
          categoriaCtrl.text.trim().isEmpty ? null : categoriaCtrl.text.trim();
      existente.estado = estado;
      existente.prioridad = prioridad;
      existente.fechaObjetivo = fechaObjetivo;
      existente.profesorId = profesorId;
      existente.tempoActual = tempoActual;
      existente.tempoObjetivo = tempoObjetivo;
      await _db.updatePreparacion(existente);
    }

    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final elementosFiltrados =
        _elementos.where((e) => e.tipo == widget.tipo).toList();

    final preparacionesActivas = elementosFiltrados.fold<int>(
      0,
      (sum, e) =>
          sum +
          (_preparacionesPorElemento[e.id]?.where((p) => p.activa).length ?? 0),
    );
    final proximaFecha = _proximaFechaLimite(elementosFiltrados);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tipo == 'obra' ? 'Repertorio' : 'Ejercicio'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearOEditarElemento(),
        child: const Icon(Icons.add),
      ),
      body: elementosFiltrados.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  'Todavía no agregaste ninguna ${widget.tipo == "obra" ? "obra" : "ejercicio"}.\nTocá + para agregar la primera.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : Column(
              children: [
                // ---- Resumen tipo dashboard ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: widget.tipo == 'obra'
                              ? Icons.library_music
                              : Icons.fitness_center,
                          value: '${elementosFiltrados.length}',
                          label: widget.tipo == 'obra' ? 'Obras' : 'Ejercicios',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.bolt,
                          value: '$preparacionesActivas',
                          label: 'Activas',
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.event,
                          value: proximaFecha == null
                              ? '—'
                              : _formatFechaCorta(proximaFecha),
                          label: 'Próx. límite',
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: elementosFiltrados.length,
                    itemBuilder: (ctx, i) {
                      final elemento = elementosFiltrados[i];
                      final preps =
                          _preparacionesPorElemento[elemento.id] ?? [];
                      final completadas =
                          preps.where((p) => p.estado == 'finalizada').length;
                      final activasCount = preps.where((p) => p.activa).length;

                      return Card(
                        child: ExpansionTile(
                          title: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      elemento.nombre,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _TipoBadge(elemento.tipo),
                                        if (elemento.compositor != null)
                                          Text(
                                            elemento.compositor!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        _PrioridadDots(elemento.prioridad),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) async {
                                  if (value == 'editar') {
                                    await _crearOEditarElemento(
                                        existente: elemento);
                                  } else if (value == 'eliminar') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: AppColors.surface,
                                        title: const Text('Eliminar elemento'),
                                        content: const Text(
                                            '¿Querés borrar esta obra/ejercicio y todas sus preparaciones?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _db.deleteElemento(elemento.id);
                                    }
                                  }
                                  _cargar();
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'editar', child: Text('Editar')),
                                  PopupMenuItem(
                                      value: 'eliminar',
                                      child: Text('Eliminar')),
                                ],
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preps.isEmpty
                                      ? 'Sin preparaciones todavía'
                                      : '${preps.length} preparación${preps.length == 1 ? '' : 'es'} · $activasCount activa${activasCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (preps.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: completadas / preps.length,
                                      minHeight: 4,
                                      backgroundColor: AppColors.surface2,
                                      valueColor: const AlwaysStoppedAnimation(
                                          AppColors.success),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                                  0, AppSpacing.md, AppSpacing.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: AppSpacing.md,
                                    runSpacing: AppSpacing.xs,
                                    children: [
                                      if (elemento.compases != null)
                                        _DetalleChip(
                                            'Compases', '${elemento.compases}'),
                                      if (elemento.tonalidad != null)
                                        _DetalleChip(
                                            'Tonalidad', elemento.tonalidad!),
                                      if (elemento.tempo != null)
                                        _DetalleChip('Tempo', elemento.tempo!),
                                      if (elemento.duracionAprox != null)
                                        _DetalleChip('Duración aprox.',
                                            '${elemento.duracionAprox} min'),
                                      if (elemento.tipo == 'obra' &&
                                          elemento.anio != null)
                                        _DetalleChip('Año', '${elemento.anio}'),
                                    ],
                                  ),
                                  if (elemento.notas.trim().isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(elemento.notas,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...preps.map((p) => _PreparacionRow(
                                  preparacion: p,
                                  onToggleActiva: (v) => _toggleActiva(p, v),
                                  onEditar: () => _crearOEditarPreparacion(
                                      elemento,
                                      existente: p),
                                  onEliminar: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: AppColors.surface,
                                        title:
                                            const Text('Eliminar preparación'),
                                        content: const Text(
                                            '¿Querés borrar esta preparación y todos sus detalles?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _db.deletePreparacion(p.id);
                                      _cargar();
                                    }
                                  },
                                  onTap: () {
                                    Navigator.of(context)
                                        .push(MaterialPageRoute(
                                          builder: (_) => PreparacionScreen(
                                            preparacionId: p.id,
                                          ),
                                        ))
                                        .then((_) => _cargar());
                                  },
                                )),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.add,
                                  color: AppColors.primary),
                              title: const Text('Nueva preparación'),
                              onTap: () => _crearOEditarPreparacion(elemento),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
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

/// Badge que distingue una obra de un ejercicio.
class _TipoBadge extends StatelessWidget {
  final String tipo;
  const _TipoBadge(this.tipo);

  @override
  Widget build(BuildContext context) {
    final esObra = tipo == 'obra';
    final color = esObra ? AppColors.primary : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        esObra ? 'Obra' : 'Ejercicio',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Indicador visual de prioridad (1 a 5) con puntos coloreados.
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

/// Badge de estado de una preparación, con ícono y color semántico.
class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge(this.estado);

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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip neutro para mostrar la categoría asignada a una preparación.
class _CategoriaChip extends StatelessWidget {
  final String categoria;
  const _CategoriaChip(this.categoria);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today,
              size: 10, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            categoria,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Chip de fecha límite: cambia de color según la urgencia.
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
      texto = _formatFechaCorta(fecha);
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de una preparación dentro de la card del elemento.
/// Reemplaza el antiguo ícono de play/pause por un switch con etiqueta
/// explícita ("Activa" / "Pausada"), más un badge de estado con ícono y color.
class _PreparacionRow extends StatelessWidget {
  final Preparacion preparacion;
  final ValueChanged<bool> onToggleActiva;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onTap;

  const _PreparacionRow({
    required this.preparacion,
    required this.onToggleActiva,
    required this.onEditar,
    required this.onEliminar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = preparacion;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
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
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _EstadoBadge(p.estado),
                      if (p.categoria != null) _CategoriaChip(p.categoria!),
                      _PrioridadDots(p.prioridad),
                      if (p.fechaObjetivo != null)
                        _DeadlineChip(p.fechaObjetivo!),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: p.activa,
                    onChanged: onToggleActiva,
                    activeColor: AppColors.primary,
                  ),
                ),
                Text(
                  p.activa ? 'Activa' : 'Pausada',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color:
                        p.activa ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'editar') {
                  onEditar();
                } else if (value == 'eliminar') {
                  onEliminar();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetalleChip extends StatelessWidget {
  final String label;
  final String valor;
  const _DetalleChip(this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label: $valor',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}
