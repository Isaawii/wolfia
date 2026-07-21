import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';

/// Fase A del plan de auditoría: pantalla que agrupa las entidades de
/// dominio nuevas (Problema, Patrón, Capacidad, Categoría, Profesor) en
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
                  items: _intensidades
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => intensidad = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: estado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: _estadosProblema
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
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

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearOEditar(),
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const _EmptyHint(
              texto:
                  'Todavía no registraste ningún problema técnico o musical.')
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final p = _items[i];
                return Card(
                  child: ListTile(
                    onTap: () => _crearOEditar(existente: p),
                    leading: CircleAvatar(
                      backgroundColor: _colorIntensidad(p.intensidad),
                      child: Text(p.intensidad[0].toUpperCase(),
                          style: const TextStyle(color: Colors.black)),
                    ),
                    title: Text(p.descripcion),
                    subtitle: Text('${p.categoria} · ${p.estado}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.textSecondary),
                      onPressed: () async {
                        await _db.deleteProblema(p.id);
                        _cargar();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// Patrones tab removed.

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

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearOEditar(),
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const _EmptyHint(
              texto: 'Todavía no registraste ninguna capacidad en desarrollo.')
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final c = _items[i];
                return Card(
                  child: ListTile(
                    onTap: () => _crearOEditar(existente: c),
                    title: Text(c.nombre),
                    subtitle: LinearProgressIndicator(
                      value: c.progreso / 100,
                      backgroundColor: AppColors.surface2,
                      color: AppColors.primary,
                    ),
                    trailing: Text('${c.progreso}%',
                        style: const TextStyle(color: AppColors.primary)),
                  ),
                );
              },
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

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
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
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final c = _items[i];
                return Card(
                  child: ListTile(
                    onTap: () => _crearOEditar(existente: c),
                    title: Text(c.nombre),
                    subtitle: Text(
                        '${c.diasList.join(", ")} · ${c.minutosObjetivo} min/semana'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.textSecondary),
                      onPressed: () async {
                        await _db.deleteCategoria(c.id);
                        _cargar();
                      },
                    ),
                  ),
                );
              },
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
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await _db.getProfesores();
    setState(() {
      _items = items;
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
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _RecomendacionesScreen(profesor: profesor)));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearOEditar(),
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const _EmptyHint(texto: 'Todavía no cargaste ningún profesor.')
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final p = _items[i];
                return Card(
                  child: ListTile(
                    title: Text(p.nombre),
                    subtitle: Text(p.contacto ?? 'Sin contacto'),
                    onTap: () => _abrirRecomendaciones(p),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                );
              },
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.profesor.nombre)),
      floatingActionButton:
          FloatingActionButton(onPressed: _crear, child: const Icon(Icons.add)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const _EmptyHint(
                  texto: 'Todavía no hay recomendaciones de este profesor.')
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final r = _items[i];
                    return Card(
                      child: ListTile(
                        title: Text(r.texto),
                        subtitle:
                            Text('Estado: ${r.estado} · toca para cambiar'),
                        onTap: () => _cambiarEstado(r),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.textSecondary),
                          onPressed: () async {
                            await _db.deleteRecomendacion(r.id);
                            _cargar();
                          },
                        ),
                      ),
                    );
                  },
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
