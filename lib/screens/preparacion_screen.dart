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
    setState(() {
      _prep = prep;
      _elemento = elemento;
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

  Future<void> _editarPreparacion() async {
    final nombreCtrl = TextEditingController(text: _prep?.nombre ?? '');
    final objetivoCtrl = TextEditingController(text: _prep?.objetivoPrincipal ?? '');
    final categoriaCtrl = TextEditingController(text: _prep?.categoria ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Editar preparación'),
        content: Column(
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
            TextField(
              controller: categoriaCtrl,
              decoration: const InputDecoration(
                labelText: 'Categoría (opcional)',
              ),
            ),
          ],
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

    if (ok == true && _prep != null && nombreCtrl.text.trim().isNotEmpty) {
      _prep!.nombre = nombreCtrl.text.trim();
      _prep!.objetivoPrincipal =
          objetivoCtrl.text.trim().isEmpty ? null : objetivoCtrl.text.trim();
      _prep!.categoria =
          categoriaCtrl.text.trim().isEmpty ? null : categoriaCtrl.text.trim();
      await _db.updatePreparacion(_prep!);
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
        text: segmento?.compasInicio != null ? '${segmento!.compasInicio}' : '');
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
    if (_elemento == null || _elemento!.compases == null || _elemento!.compases! <= 0) {
      return const SizedBox.shrink();
    }
    final total = _elemento!.compases!;
    final visibles = _segmentos.where((s) => s.compasInicio != null && s.compasFin != null && s.compasFin! > s.compasInicio!).toList();
    if (visibles.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Diagrama de compases', style: Theme.of(context).textTheme.titleMedium),
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
                  color: AppColors.bg.withOpacity(0.1),
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
                      color: _colorForPrioridad(s.prioridad).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Total: $total compases', style: Theme.of(context).textTheme.bodyMedium),
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
                  icon: const Icon(Icons.add),
                  onPressed: () => _agregarOEditarSegmento()),
            ],
          ),
          if (_elemento != null && _elemento!.compases != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _buildDiagrama(),
            ),
          ..._segmentos.map((s) => Card(
                child: ListTile(
                  title: Text(s.nombre),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prioridad ${s.prioridad}/5 · ${s.diasSinPracticar() >= 999 ? 'sin practicar' : 'hace ${s.diasSinPracticar()} días'}',
                      ),
                      if (s.compasInicio != null || s.compasFin != null)
                        Text('Compases: ${s.compasInicio ?? '?'} - ${s.compasFin ?? '?'}'),
                    ],
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
                            content: const Text(
                                '¿Querés borrar este segmento?'),
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
              )),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Preparaciones', style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar preparación',
                      onPressed: _editarPreparacion),
                  IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eliminar preparación',
                      onPressed: _eliminarPreparacion),
                ],
              )
            ],
          ),
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
