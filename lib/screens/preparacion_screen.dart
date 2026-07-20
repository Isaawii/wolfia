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
  List<Segmento> _segmentos = [];
  List<Objetivo> _objetivos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todas = await _db.getTodasPreparaciones();
    final prep = todas.firstWhere((p) => p.id == widget.preparacionId);
    final segmentos = await _db.getSegmentos(widget.preparacionId);
    final objetivos = await _db.getObjetivos(widget.preparacionId);
    setState(() {
      _prep = prep;
      _segmentos = segmentos;
      _objetivos = objetivos;
      _cargando = false;
    });
  }

  Future<void> _toggleActiva() async {
    _prep!.activa = !_prep!.activa;
    await _db.updatePreparacion(_prep!);
    _cargar();
  }

  Future<void> _agregarSegmento() async {
    final nombreCtrl = TextEditingController();
    int prioridad = 3;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Nuevo segmento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nombre (ej: Compases 34-48)'),
                autofocus: true,
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

    if (ok == true && nombreCtrl.text.trim().isNotEmpty) {
      final seg = Segmento(
        id: _uuid.v4(),
        preparacionId: widget.preparacionId,
        nombre: nombreCtrl.text.trim(),
        prioridad: prioridad,
        estado: 'activo',
      );
      await _db.insertSegmento(seg);
      _cargar();
    }
  }

  Future<void> _agregarObjetivo() async {
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nuevo objetivo'),
        content: TextField(
          controller: descCtrl,
          decoration: const InputDecoration(labelText: 'Ej: Negra = 108'),
          autofocus: true,
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
      final obj = Objetivo(
        id: _uuid.v4(),
        preparacionId: widget.preparacionId,
        descripcion: descCtrl.text.trim(),
      );
      await _db.insertObjetivo(obj);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(prep.nombre),
        actions: [
          IconButton(
            icon: Icon(prep.activa ? Icons.pause : Icons.play_arrow),
            tooltip: prep.activa ? 'Archivar' : 'Activar',
            onPressed: _toggleActiva,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (prep.objetivoPrincipal != null) ...[
            Text('Objetivo principal',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(prep.objetivoPrincipal!,
                style: const TextStyle(color: AppColors.primary)),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Segmentos', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                  icon: const Icon(Icons.add), onPressed: _agregarSegmento),
            ],
          ),
          ..._segmentos.map((s) => Card(
                child: ListTile(
                  title: Text(s.nombre),
                  subtitle: Text(
                      'Prioridad ${s.prioridad}/5 · ${s.diasSinPracticar() >= 999 ? 'sin practicar' : 'hace ${s.diasSinPracticar()} días'}'),
                  trailing: Text(s.estado),
                ),
              )),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Objetivos', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                  icon: const Icon(Icons.add), onPressed: _agregarObjetivo),
            ],
          ),
          ..._objetivos.map((o) => CheckboxListTile(
                value: o.estado == 'cumplido',
                onChanged: (_) => _toggleObjetivo(o),
                title: Text(
                  o.descripcion,
                  style: TextStyle(
                    decoration: o.estado == 'cumplido'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                activeColor: AppColors.primary,
              )),
        ],
      ),
    );
  }
}
