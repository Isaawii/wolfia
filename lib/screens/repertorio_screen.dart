import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';
import 'preparacion_screen.dart';

class RepertorioScreen extends StatefulWidget {
  const RepertorioScreen({super.key});

  @override
  State<RepertorioScreen> createState() => _RepertorioScreenState();
}

class _RepertorioScreenState extends State<RepertorioScreen> {
  final _db = WolfiaDb.instance;
  final _uuid = const Uuid();
  List<Elemento> _elementos = [];
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
    final mapa = <String, List<Preparacion>>{};
    for (final p in todasPreps) {
      mapa.putIfAbsent(p.elementoId, () => []).add(p);
    }
    setState(() {
      _elementos = elementos;
      _preparacionesPorElemento = mapa;
      _cargando = false;
    });
  }

  Future<void> _crearElemento() async {
    final nombreCtrl = TextEditingController();
    final compositorCtrl = TextEditingController();
    String tipo = 'obra';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Nuevo elemento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'obra', label: Text('Obra')),
                  ButtonSegment(value: 'ejercicio', label: Text('Ejercicio')),
                ],
                selected: {tipo},
                onSelectionChanged: (s) => setStateDialog(() => tipo = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                autofocus: true,
              ),
              if (tipo == 'obra')
                TextField(
                  controller: compositorCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Compositor (opcional)'),
                ),
            ],
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
      ),
    );

    if (result == true && nombreCtrl.text.trim().isNotEmpty) {
      final elemento = Elemento(
        id: _uuid.v4(),
        nombre: nombreCtrl.text.trim(),
        tipo: tipo,
        compositor: compositorCtrl.text.trim().isEmpty
            ? null
            : compositorCtrl.text.trim(),
      );
      await _db.insertElemento(elemento);
      _cargar();
    }
  }

  Future<void> _crearPreparacion(Elemento elemento) async {
    final nombreCtrl = TextEditingController(text: 'Preparación');
    final objetivoCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Nueva preparación · ${elemento.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nombreCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nombre (ej: Recital)')),
            TextField(
                controller: objetivoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Objetivo principal (opcional)')),
          ],
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

    if (result == true && nombreCtrl.text.trim().isNotEmpty) {
      final prep = Preparacion(
        id: _uuid.v4(),
        elementoId: elemento.id,
        nombre: nombreCtrl.text.trim(),
        objetivoPrincipal:
            objetivoCtrl.text.trim().isEmpty ? null : objetivoCtrl.text.trim(),
      );
      await _db.insertPreparacion(prep);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('Repertorio')),
      floatingActionButton: FloatingActionButton(
        onPressed: _crearElemento,
        child: const Icon(Icons.add),
      ),
      body: _elementos.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  'Todavía no agregaste ninguna obra ni ejercicio.\n'
                  'Tocá + para agregar el primero.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _elementos.length,
              itemBuilder: (ctx, i) {
                final elemento = _elementos[i];
                final preps = _preparacionesPorElemento[elemento.id] ?? [];
                return Card(
                  child: ExpansionTile(
                    title: Text(elemento.nombre),
                    subtitle: Text(
                      [
                        elemento.tipo == 'obra' ? 'Obra' : 'Ejercicio',
                        if (elemento.compositor != null) elemento.compositor!,
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
                            onTap: () {
                              Navigator.of(context)
                                  .push(MaterialPageRoute(
                                    builder: (_) =>
                                        PreparacionScreen(preparacionId: p.id),
                                  ))
                                  .then((_) => _cargar());
                            },
                          )),
                      ListTile(
                        leading:
                            const Icon(Icons.add, color: AppColors.primary),
                        title: const Text('Nueva preparación'),
                        onTap: () => _crearPreparacion(elemento),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
