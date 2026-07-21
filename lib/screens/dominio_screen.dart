import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';

/// Fase A del plan de auditoría: pantalla que agrupa las entidades de
/// dominio nuevas (Problema, Capacidad, Categoría, Profesor) en
/// un único hub con pestañas, con CRUD básico sobre SQLite.
/// Todavía no están conectadas al generador de sesiones (eso es Fase C).
class DominioScreen extends StatefulWidget {
  const DominioScreen({super.key});

  @override
  State<DominioScreen> createState() => _DominioScreenState();
}

class _DominioScreenState extends State<DominioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dominio'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Problemas'),
            Tab(text: 'Capacidades'),
            Tab(text: 'Categorías'),
            Tab(text: 'Profesores'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ProblemasTab(),
          _CapacidadesTab(),
          _CategoriasTab(),
          _ProfesoresTab(),
        ],
      ),
    );
  }
}

const _categoriasProblema = [
  'tecnica',
  'musicalidad',
  'memoria',
  'lectura',
  'interpretacion',
  'postura',
  'sonido',
  'ritmo',
  'pedal',
  'digitacion',
];
const _intensidades = ['leve', 'media', 'alta', 'critica'];
const _estadosProblema = ['activo', 'en_progreso', 'resuelto'];

Color _colorIntensidad(String i) {
  switch (i) {
    case 'critica':
      return AppColors.error;
    case 'alta':
      return AppColors.warning;
    case 'media':
      return AppColors.info;
    default:
      return AppColors.success;
  }
}

IconData _iconoIntensidad(String i) {
  switch (i) {
    case 'critica':
      return Icons.warning_amber_rounded;
    case 'alta':
      return Icons.priority_high;
    case 'media':
      return Icons.info_outline;
    default:
      return Icons.check_circle_outline;
  }
}

Color _colorEstadoProblema(String e) {
  switch (e) {
    case 'activo':
      return AppColors.warning;
    case 'en_progreso':
      return AppColors.info;
    case 'resuelto':
      return AppColors.success;
    default:
      return AppColors.textSecondary;
  }
}

IconData _iconoEstadoProblema(String e) {
  switch (e) {
    case 'activo':
      return Icons.schedule;
    case 'en_progreso':
      return Icons.autorenew;
    case 'resuelto':
      return Icons.check_circle;
    default:
      return Icons.circle;
  }
}

Color _colorEstadoRecomendacion(String e) {
  switch (e) {
    case 'aplicada':
      return AppColors.success;
    case 'descartada':
      return AppColors.textSecondary;
    default:
      return AppColors.warning;
  }
}

IconData _iconoEstadoRecomendacion(String e) {
  switch (e) {
    case 'aplicada':
      return Icons.check_circle;
    case 'descartada':
      return Icons.block;
    default:
      return Icons.schedule;
  }
}

// ---------------------------------------------------------------------------
// Problemas
// ---------------------------------------------------------------------------

class _ProblemasTab extends StatefulWidget {
  const _ProblemasTab();
  @override
  State<_ProblemasTab> createState() => _ProblemasTabState();
}

class _ProblemasTabState extends State<_ProblemasTab> {
  final _db = WolfiaDb.instance;
  final _uuid = const Uuid();
  List<Problema> _items = [];
  List<Preparacion> _preparaciones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await _db.getProblemas();
    final preps = await _db.getTodasPreparaciones();
    setState(() {
      _items = items;
      _preparaciones = preps;
      _cargando = false;
    });
  }

  Future<void> _crearOEditar({Problema? existente}) async {
    final descCtrl = TextEditingController(text: existente?.descripcion ?? '');
    final solCtrl = TextEditingController(text: existente?.soluciones ?? '');
    final ejCtrl =
        TextEditingController(text: existente?.ejerciciosRelacionados ?? '');
    String categoria = existente?.categoria ?? 'tecnica';
    String intensidad = existente?.intensidad ?? 'media';
    String estado = existente?.estado ?? 'activo';
    String? preparacionId = existente?.preparacionId;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(existente == null ? 'Nuevo problema' : 'Editar problema'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: descCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: _categoriasProblema
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => categoria = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: intensidad,
                  decoration: const InputDecoration(labelText: 'Intensidad'),
                  items: _intensidades.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_iconoIntensidad(c),
                              size: 16, color: _colorIntensidad(c)),
                          const SizedBox(width: AppSpacing.xs),
                          Text(c),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setStateDialog(() => intensidad = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: estado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: _estadosProblema.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_iconoEstadoProblema(c),
                              size: 16, color: _colorEstadoProblema(c)),
                          const SizedBox(width: AppSpacing.xs),
                          Text(c),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setStateDialog(() => estado = v!),
                ),
                DropdownButtonFormField<String?>(
                  initialValue: preparacionId,
                  decoration: const InputDecoration(labelText: 'Preparación'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Ninguna')),
                    ..._preparaciones.map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.nombre))),
                  ],
                  onChanged: (v) => setStateDialog(() => preparacionId = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: solCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Soluciones probadas'),
                  maxLines: 2,
                ),
                TextField(
                  controller: ejCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Ejercicios relacionados'),
                  maxLines: 2,
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

    if (result == true && descCtrl.text.trim().isNotEmpty) {
      if (existente == null) {
        await _db.insertProblema(Problema(
          id: _uuid.v4(),
          descripcion: descCtrl.text.trim(),
          categoria: categoria,
          intensidad: intensidad,
          estado: estado,
          preparacionId: preparacionId,
          soluciones: solCtrl.text.trim(),
          ejerciciosRelacionados: ejCtrl.text.trim(),
        ));
      } else {
        existente.descripcion = descCtrl.text.trim();
        existente.categoria = categoria;
        existente.intensidad = intensidad;
        existente.estado = estado;
        existente.preparacionId = preparacionId;
        existente.soluciones = solCtrl.text.trim();
        existente.ejerciciosRelacionados = ejCtrl.text.trim();
        await _db.updateProblema(existente);
      }
      _cargar();
    }
  }

  Future<void> _eliminar(Problema p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar problema'),
        content: const Text('¿Querés borrar este problema?'),
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
      await _db.deleteProblema(p.id);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final activos = _items.where((p) => p.estado == 'activo').length;
    final criticos = _items.where((p) => p.intensidad == 'critica').length;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearOEditar(),
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const _EmptyHint(
              texto:
                  'Todavía no registraste ningún problema técnico o musical.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.report_problem_outlined,
                          value: '${_items.length}',
                          label: 'Problemas',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.schedule,
                          value: '$activos',
                          label: 'Activos',
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.warning_amber_rounded,
                          value: '$criticos',
                          label: 'Críticos',
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final p = _items[i];
                      final color = _colorIntensidad(p.intensidad);
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _crearOEditar(existente: p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: color.withOpacity(0.15),
                                  child: Icon(_iconoIntensidad(p.intensidad),
                                      color: color, size: 20),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.descripcion,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          _EstadoProblemaBadge(p.estado),
                                          _IntensidadBadge(p.intensidad),
                                          _CategoriaProblemaChip(p.categoria),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    if (value == 'editar') {
                                      _crearOEditar(existente: p);
                                    } else if (value == 'eliminar') {
                                      _eliminar(p);
                                    }
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
                          ),
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

// ---------------------------------------------------------------------------
// Capacidades
// ---------------------------------------------------------------------------

class _CapacidadesTab extends StatefulWidget {
  const _CapacidadesTab();
  @override
  State<_CapacidadesTab> createState() => _CapacidadesTabState();
}

class _CapacidadesTabState extends State<_CapacidadesTab> {
  final _db = WolfiaDb.instance;
  final _uuid = const Uuid();
  List<Capacidad> _items = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await _db.getCapacidades();
    setState(() {
      _items = items;
      _cargando = false;
    });
  }

  Future<void> _crearOEditar({Capacidad? existente}) async {
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final descCtrl = TextEditingController(text: existente?.descripcion ?? '');
    final notasCtrl = TextEditingController(text: existente?.notas ?? '');
    double progreso = (existente?.progreso ?? 0).toDouble();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title:
              Text(existente == null ? 'Nueva capacidad' : 'Editar capacidad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nombreCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Nombre (ej: Lectura a primera vista)')),
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2),
              const SizedBox(height: AppSpacing.sm),
              Text('Progreso: ${progreso.round()}%'),
              Slider(
                value: progreso,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: AppColors.primary,
                onChanged: (v) => setStateDialog(() => progreso = v),
              ),
              TextField(
                  controller: notasCtrl,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 2),
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
      ),
    );

    if (result == true && nombreCtrl.text.trim().isNotEmpty) {
      if (existente == null) {
        await _db.insertCapacidad(Capacidad(
          id: _uuid.v4(),
          nombre: nombreCtrl.text.trim(),
          descripcion: descCtrl.text.trim(),
          progreso: progreso.round(),
          notas: notasCtrl.text.trim(),
        ));
      } else {
        existente.nombre = nombreCtrl.text.trim();
        existente.descripcion = descCtrl.text.trim();
        existente.progreso = progreso.round();
        existente.notas = notasCtrl.text.trim();
        await _db.updateCapacidad(existente);
      }
      _cargar();
    }
  }

  Color _colorProgreso(int progreso) {
    if (progreso >= 75) return AppColors.success;
    if (progreso >= 40) return AppColors.primary;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final promedio = _items.isEmpty
        ? 0
        : (_items.fold<int>(0, (a, c) => a + c.progreso) / _items.length)
            .round();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearOEditar(),
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const _EmptyHint(
              texto: 'Todavía no registraste ninguna capacidad en desarrollo.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.auto_awesome_outlined,
                          value: '${_items.length}',
                          label: 'Capacidades',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.trending_up,
                          value: '$promedio%',
                          label: 'Progreso prom.',
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final c = _items[i];
                      final color = _colorProgreso(c.progreso);
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _crearOEditar(existente: c),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text),
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: c.progreso / 100,
                                          minHeight: 6,
                                          backgroundColor: AppColors.surface2,
                                          valueColor:
                                              AlwaysStoppedAnimation(color),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${c.progreso}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

// ---------------------------------------------------------------------------
// Categorías
// ---------------------------------------------------------------------------

const _diasSemana = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];

class _CategoriasTab extends StatefulWidget {
  const _CategoriasTab();
  @override
  State<_CategoriasTab> createState() => _CategoriasTabState();
}

class _CategoriasTabState extends State<_CategoriasTab> {
  final _db = WolfiaDb.instance;
  final _uuid = const Uuid();
  List<Categoria> _items = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await _db.getCategorias();
    setState(() {
      _items = items;
      _cargando = false;
    });
  }

  Future<void> _crearOEditar({Categoria? existente}) async {
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final minutosCtrl = TextEditingController(
        text: (existente?.minutosObjetivo ?? 60).toString());
    final diasSeleccionados =
        (existente?.diasList ?? List.of(_diasSemana)).toSet();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title:
              Text(existente == null ? 'Nueva categoría' : 'Editar categoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                  controller: nombreCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Nombre (ej: Técnica, Repertorio, Lectura)')),
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

    if (result == true && nombreCtrl.text.trim().isNotEmpty) {
      final diasOrdenados =
          _diasSemana.where((d) => diasSeleccionados.contains(d)).join(',');
      final minutos = int.tryParse(minutosCtrl.text.trim()) ?? 0;
      if (existente == null) {
        await _db.insertCategoria(Categoria(
          id: _uuid.v4(),
          nombre: nombreCtrl.text.trim(),
          diasSemana: diasOrdenados,
          minutosObjetivo: minutos,
        ));
      } else {
        existente.nombre = nombreCtrl.text.trim();
        existente.diasSemana = diasOrdenados;
        existente.minutosObjetivo = minutos;
        await _db.updateCategoria(existente);
      }
      _cargar();
    }
  }

  Future<void> _eliminar(Categoria c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar categoría'),
        content: const Text('¿Querés borrar esta categoría?'),
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
      await _db.deleteCategoria(c.id);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final minutosTotales = _items.fold<int>(0, (a, c) => a + c.minutosObjetivo);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearOEditar(),
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const _EmptyHint(
              texto:
                  'Todavía no definiste categorías con reglas de calendario.\n'
                  'El generador de sesiones las usará en una fase futura.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.category_outlined,
                          value: '${_items.length}',
                          label: 'Categorías',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.timer_outlined,
                          value: '$minutosTotales',
                          label: 'Min/semana',
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final c = _items[i];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _crearOEditar(existente: c),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          _DetalleChip(
                                              'Días', c.diasList.join(', ')),
                                          _DetalleChip('Objetivo',
                                              '${c.minutosObjetivo} min/sem'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.textSecondary),
                                  onPressed: () => _eliminar(c),
                                ),
                              ],
                            ),
                          ),
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

// ---------------------------------------------------------------------------
// Profesores + Recomendaciones
// ---------------------------------------------------------------------------

class _ProfesoresTab extends StatefulWidget {
  const _ProfesoresTab();
  @override
  State<_ProfesoresTab> createState() => _ProfesoresTabState();
}

class _ProfesoresTabState extends State<_ProfesoresTab> {
  final _db = WolfiaDb.instance;
  final _uuid = const Uuid();
  List<Profesor> _items = [];
  Map<String, int> _pendientesPorProfesor = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await _db.getProfesores();
    final mapa = <String, int>{};
    for (final p in items) {
      final recs = await _db.getRecomendaciones(p.id);
      mapa[p.id] = recs.where((r) => r.estado == 'pendiente').length;
    }
    setState(() {
      _items = items;
      _pendientesPorProfesor = mapa;
      _cargando = false;
    });
  }

  Future<void> _crearOEditar({Profesor? existente}) async {
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final contactoCtrl = TextEditingController(text: existente?.contacto ?? '');
    final notasCtrl = TextEditingController(text: existente?.notas ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(existente == null ? 'Nuevo profesor' : 'Editar profesor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nombreCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(
                controller: contactoCtrl,
                decoration: const InputDecoration(labelText: 'Contacto')),
            TextField(
                controller: notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 2),
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

    if (result == true && nombreCtrl.text.trim().isNotEmpty) {
      if (existente == null) {
        await _db.insertProfesor(Profesor(
          id: _uuid.v4(),
          nombre: nombreCtrl.text.trim(),
          contacto: contactoCtrl.text.trim().isEmpty
              ? null
              : contactoCtrl.text.trim(),
          notas: notasCtrl.text.trim(),
        ));
      } else {
        existente.nombre = nombreCtrl.text.trim();
        existente.contacto =
            contactoCtrl.text.trim().isEmpty ? null : contactoCtrl.text.trim();
        existente.notas = notasCtrl.text.trim();
        await _db.updateProfesor(existente);
      }
      _cargar();
    }
  }

  void _abrirRecomendaciones(Profesor profesor) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => _RecomendacionesScreen(profesor: profesor)))
        .then((_) => _cargar());
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final pendientesTotales =
        _pendientesPorProfesor.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearOEditar(),
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const _EmptyHint(texto: 'Todavía no cargaste ningún profesor.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.school_outlined,
                          value: '${_items.length}',
                          label: 'Profesores',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.lightbulb_outline,
                          value: '$pendientesTotales',
                          label: 'Recom. pendientes',
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final p = _items[i];
                      final pendientes = _pendientesPorProfesor[p.id] ?? 0;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _abrirRecomendaciones(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.15),
                                  child: Text(
                                    p.nombre.isNotEmpty
                                        ? p.nombre[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p.contacto ?? 'Sin contacto',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                      if (pendientes > 0) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '$pendientes recomendación${pendientes == 1 ? '' : 'es'} pendiente${pendientes == 1 ? '' : 's'}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AppColors.textSecondary),
                                  onPressed: () => _crearOEditar(existente: p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.textSecondary),
                                  onPressed: () async {
                                    await _db.deleteProfesor(p.id);
                                    _cargar();
                                  },
                                ),
                              ],
                            ),
                          ),
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

class _RecomendacionesScreen extends StatefulWidget {
  final Profesor profesor;
  const _RecomendacionesScreen({required this.profesor});

  @override
  State<_RecomendacionesScreen> createState() => _RecomendacionesScreenState();
}

class _RecomendacionesScreenState extends State<_RecomendacionesScreen> {
  final _db = WolfiaDb.instance;
  final _uuid = const Uuid();
  List<Recomendacion> _items = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await _db.getRecomendaciones(widget.profesor.id);
    setState(() {
      _items = items;
      _cargando = false;
    });
  }

  Future<void> _crear() async {
    final textoCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nueva recomendación'),
        content: TextField(
          controller: textoCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '¿Qué recomendó?'),
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

    if (result == true && textoCtrl.text.trim().isNotEmpty) {
      await _db.insertRecomendacion(Recomendacion(
        id: _uuid.v4(),
        profesorId: widget.profesor.id,
        texto: textoCtrl.text.trim(),
      ));
      _cargar();
    }
  }

  Future<void> _cambiarEstado(Recomendacion r) async {
    const estados = ['pendiente', 'aplicada', 'descartada'];
    final actual = estados.indexOf(r.estado);
    r.estado = estados[(actual + 1) % estados.length];
    await _db.updateRecomendacion(r);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _items.where((r) => r.estado == 'pendiente').length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.profesor.nombre)),
      floatingActionButton:
          FloatingActionButton(onPressed: _crear, child: const Icon(Icons.add)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const _EmptyHint(
                  texto: 'Todavía no hay recomendaciones de este profesor.')
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.lightbulb_outline,
                              value: '${_items.length}',
                              label: 'Total',
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.schedule,
                              value: '$pendientes',
                              label: 'Pendientes',
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final r = _items[i];
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _cambiarEstado(r),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(r.texto,
                                              style: const TextStyle(
                                                  color: AppColors.text)),
                                          const SizedBox(height: 6),
                                          _RecomendacionEstadoBadge(r.estado),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: AppColors.textSecondary),
                                      onPressed: () async {
                                        await _db.deleteRecomendacion(r.id);
                                        _cargar();
                                      },
                                    ),
                                  ],
                                ),
                              ),
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

// ---------------------------------------------------------------------------
// Widgets compartidos (mismo lenguaje visual que repertorio_screen.dart)
// ---------------------------------------------------------------------------

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

/// Badge de estado de un problema, con ícono y color semántico.
class _EstadoProblemaBadge extends StatelessWidget {
  final String estado;
  const _EstadoProblemaBadge(this.estado);

  @override
  Widget build(BuildContext context) {
    final color = _colorEstadoProblema(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoEstadoProblema(estado), size: 12, color: color),
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

/// Badge de intensidad de un problema, con ícono y color semántico.
class _IntensidadBadge extends StatelessWidget {
  final String intensidad;
  const _IntensidadBadge(this.intensidad);

  @override
  Widget build(BuildContext context) {
    final color = _colorIntensidad(intensidad);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoIntensidad(intensidad), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            intensidad,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Chip neutro para mostrar la categoría de un problema.
class _CategoriaProblemaChip extends StatelessWidget {
  final String categoria;
  const _CategoriaProblemaChip(this.categoria);

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
          const Icon(Icons.label_outline,
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

/// Badge de estado de una recomendación, con ícono y color semántico.
class _RecomendacionEstadoBadge extends StatelessWidget {
  final String estado;
  const _RecomendacionEstadoBadge(this.estado);

  @override
  Widget build(BuildContext context) {
    final color = _colorEstadoRecomendacion(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoEstadoRecomendacion(estado), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$estado · toca para cambiar',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Chip genérico label:valor, igual al de repertorio_screen.dart.
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

class _EmptyHint extends StatelessWidget {
  final String texto;
  const _EmptyHint({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Text(texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}
