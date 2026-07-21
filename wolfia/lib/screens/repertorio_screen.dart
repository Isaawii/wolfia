import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'preparacion_screen.dart';

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
    final mapa = <String, List<Preparacion>>{};
    for (final p in todasPreps) {
      mapa.putIfAbsent(p.elementoId, () => []).add(p);
    }
    setState(() {
      _elementos = elementos;
      _categorias = categorias;
      _preparacionesPorElemento = mapa;
      _cargando = false;
    });
  }

  Future<void> _crearOEditarElemento({Elemento? existente}) async {
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final compositorCtrl =
        TextEditingController(text: existente?.compositor ?? '');
    final compasesCtrl = TextEditingController(
      text: existente?.compases != null ? '${existente!.compases}' : '',
    );
    final categoriaCtrl =
        TextEditingController(text: existente?.categoria ?? '');
    String tipo = existente?.tipo ?? widget.tipo;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(existente == null ? 'Nuevo elemento' : 'Editar elemento'),
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
    final categoria = categoriaCtrl.text.trim().isEmpty
        ? 'General'
        : categoriaCtrl.text.trim();

    if (existente == null) {
      final elemento = Elemento(
        id: _uuid.v4(),
        nombre: nombreCtrl.text.trim(),
        tipo: tipo,
        compositor: compositorCtrl.text.trim().isEmpty
            ? null
            : compositorCtrl.text.trim(),
        compases: compases,
        categoria: categoria,
      );
      await _db.insertElemento(elemento);
    } else {
      existente.nombre = nombreCtrl.text.trim();
      existente.tipo = tipo;
      existente.compositor = compositorCtrl.text.trim().isEmpty
          ? null
          : compositorCtrl.text.trim();
      existente.compases = compases;
      existente.categoria = categoria;
      await _db.updateElemento(existente);
    }

    _cargar();
  }

  Future<String?> _crearCategoriaRapida() async {
    final nombreCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: nombreCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
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
    );

    if (result != true || nombreCtrl.text.trim().isEmpty) return null;

    final nuevaCategoria = Categoria(
      id: _uuid.v4(),
      nombre: nombreCtrl.text.trim(),
    );
    await _db.insertCategoria(nuevaCategoria);
    return nuevaCategoria.nombre;
  }

  Future<void> _crearOEditarPreparacion(Elemento elemento,
      {Preparacion? existente}) async {
    final nombreCtrl =
        TextEditingController(text: existente?.nombre ?? 'Preparación');
    final objetivoCtrl =
        TextEditingController(text: existente?.objetivoPrincipal ?? '');
    final categoriaCtrl =
        TextEditingController(text: existente?.categoria ?? '');

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
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nombre (ej: Recital)'),
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
      );
      await _db.insertPreparacion(prep);
    } else {
      existente.nombre = nombreCtrl.text.trim();
      existente.objetivoPrincipal =
          objetivoCtrl.text.trim().isEmpty ? null : objetivoCtrl.text.trim();
      existente.categoria =
          categoriaCtrl.text.trim().isEmpty ? null : categoriaCtrl.text.trim();
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
                    subtitle: Text(
                      [
                        elemento.tipo == 'obra' ? 'Obra' : 'Ejercicio',
                        if (elemento.compositor != null) elemento.compositor!,
                        if (elemento.compases != null)
                          'Compases ${elemento.compases}',
                        if (elemento.categoria.isNotEmpty) elemento.categoria,
                      ].join(' · '),
                    ),
                    children: [
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
