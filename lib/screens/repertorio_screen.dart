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
                  items: _estadosPreparacion
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
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
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: elementosFiltrados.length,
              itemBuilder: (ctx, i) {
                final elemento = elementosFiltrados[i];
                final preps = _preparacionesPorElemento[elemento.id] ?? [];
                return Card(
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(elemento.nombre)),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) async {
                            if (value == 'editar') {
                              await _crearOEditarElemento(existente: elemento);
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
                                      onPressed: () => Navigator.pop(ctx, true),
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
                                value: 'eliminar', child: Text('Eliminar')),
                          ],
                        ),
                      ],
                    ),
                    // ---- ESTE subtitle REEMPLAZA AL VIEJO ----
                    subtitle: Text(
                      [
                        elemento.tipo == 'obra' ? 'Obra' : 'Ejercicio',
                        if (elemento.compositor != null) elemento.compositor!,
                        'Prioridad ${elemento.prioridad}/5',
                      ].join(' · '),
                    ),
                    children: [
                      // ---- ESTE BLOQUE ES NUEVO: la ficha de detalle ----
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
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
                      // ---- ESTO YA LO TENÍAS, SIGUE IGUAL ----
                      ...preps.map((p) => ListTile(
                            leading: Icon(
                              p.activa
                                  ? Icons.play_circle_outline
                                  : Icons.pause_circle_outline,
                              color: p.activa
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            title: Text(p.nombre),
                            subtitle: Text('Estado: ${p.estado}'),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'editar') {
                                  await _crearOEditarPreparacion(elemento,
                                      existente: p);
                                } else if (value == 'eliminar') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: AppColors.surface,
                                      title: const Text('Eliminar preparación'),
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
                                  }
                                }
                                _cargar();
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'editar', child: Text('Editar')),
                                PopupMenuItem(
                                    value: 'eliminar', child: Text('Eliminar')),
                              ],
                            ),
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
                        leading:
                            const Icon(Icons.add, color: AppColors.primary),
                        title: const Text('Nueva preparación'),
                        onTap: () => _crearOEditarPreparacion(elemento),
                      ),
                    ],
                  ),
                );
              },
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
