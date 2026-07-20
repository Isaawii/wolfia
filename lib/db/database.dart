import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

/// Base de datos local única. Nada de sincronización, nada de servidor:
/// todo vive en el teléfono. Para uso personal esto es exactamente lo
/// que hace falta y evita 90% de la complejidad del documento original.
class WolfiaDb {
  WolfiaDb._();
  static final WolfiaDb instance = WolfiaDb._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wolfia.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE elementos (
            id TEXT PRIMARY KEY,
            nombre TEXT NOT NULL,
            tipo TEXT NOT NULL,
            compositor TEXT,
            compases INTEGER,
            categoria TEXT NOT NULL,
            estado TEXT NOT NULL,
            notas TEXT NOT NULL,
            creado_en TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE preparaciones (
            id TEXT PRIMARY KEY,
            elemento_id TEXT NOT NULL,
            nombre TEXT NOT NULL,
            objetivo_principal TEXT,
            categoria TEXT,
            estado TEXT NOT NULL,
            activa INTEGER NOT NULL,
            fecha_objetivo TEXT,
            puntos INTEGER NOT NULL,
            prioridad INTEGER NOT NULL,
            tiempo_invertido INTEGER NOT NULL,
            sesiones_count INTEGER NOT NULL,
            profesor_id TEXT,
            ultima_practica TEXT,
            tempo_actual INTEGER,
            tempo_objetivo INTEGER,
            creado_en TEXT NOT NULL,
            FOREIGN KEY (elemento_id) REFERENCES elementos(id)
          );
        ''');
        await db.execute('''
          CREATE TABLE segmentos (
            id TEXT PRIMARY KEY,
            preparacion_id TEXT NOT NULL,
            nombre TEXT NOT NULL,
            prioridad INTEGER NOT NULL,
            estado TEXT NOT NULL,
            tempo_actual INTEGER,
            tempo_objetivo INTEGER,
            compas_inicio INTEGER,
            compas_fin INTEGER,
            ultima_practica TEXT,
            notas TEXT NOT NULL,
            FOREIGN KEY (preparacion_id) REFERENCES preparaciones(id)
          );
        ''');
        await db.execute('''
          CREATE TABLE objetivos (
            id TEXT PRIMARY KEY,
            preparacion_id TEXT NOT NULL,
            segmento_id TEXT,
            descripcion TEXT NOT NULL,
            estado TEXT NOT NULL,
            prioridad INTEGER NOT NULL,
            puntos INTEGER NOT NULL,
            puntos_por_minuto INTEGER NOT NULL,
            estado_mental TEXT,
            tiempo_minimo INTEGER NOT NULL DEFAULT 10,
            tiempo_maximo INTEGER NOT NULL DEFAULT 25,
            FOREIGN KEY (preparacion_id) REFERENCES preparaciones(id)
          );
        ''');
        await db.execute('''
          CREATE TABLE sesiones (
            id TEXT PRIMARY KEY,
            fecha TEXT NOT NULL,
            duracion_planeada INTEGER NOT NULL,
            duracion_real INTEGER,
            estado TEXT NOT NULL,
            notas TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE tareas (
            id TEXT PRIMARY KEY,
            sesion_id TEXT NOT NULL,
            preparacion_id TEXT NOT NULL,
            segmento_id TEXT,
            objetivo_id TEXT,
            titulo_preparacion TEXT NOT NULL,
            titulo_segmento TEXT,
            titulo_objetivo TEXT,
            tipo_objetivo TEXT,
            minutos_planeados INTEGER NOT NULL,
            minutos_reales INTEGER,
            completada INTEGER NOT NULL,
            motivo TEXT NOT NULL,
            resultado TEXT,
            FOREIGN KEY (sesion_id) REFERENCES sesiones(id)
          );
        ''');
        await db.execute('''
          CREATE TABLE notas (
            id TEXT PRIMARY KEY,
            contenido TEXT NOT NULL,
            preparacion_id TEXT,
            segmento_id TEXT,
            sesion_id TEXT,
            fecha TEXT NOT NULL
          );
        ''');
        await db
            .execute('CREATE INDEX idx_prep_activa ON preparaciones(activa);');
        await db
            .execute('CREATE INDEX idx_seg_prep ON segmentos(preparacion_id);');
        await db.execute('CREATE INDEX idx_tarea_sesion ON tareas(sesion_id);');
        await _crearTablasFaseA(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _crearTablasFaseA(db);
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE elementos ADD COLUMN compases INTEGER');
          await db
              .execute('ALTER TABLE preparaciones ADD COLUMN categoria TEXT');
          await db.execute(
              'ALTER TABLE segmentos ADD COLUMN compas_inicio INTEGER');
          await db
              .execute('ALTER TABLE segmentos ADD COLUMN compas_fin INTEGER');
        }
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE preparaciones ADD COLUMN prioridad INTEGER DEFAULT 3');
          await db.execute(
              'ALTER TABLE preparaciones ADD COLUMN tiempo_invertido INTEGER DEFAULT 0');
          await db.execute(
              'ALTER TABLE preparaciones ADD COLUMN sesiones_count INTEGER DEFAULT 0');
          await db
              .execute('ALTER TABLE preparaciones ADD COLUMN profesor_id TEXT');
        }
        if (oldVersion < 5) {
          await db.execute(
              'ALTER TABLE objetivos ADD COLUMN puntos INTEGER DEFAULT 0');
          await db.execute(
              'ALTER TABLE objetivos ADD COLUMN puntos_por_minuto INTEGER DEFAULT 1');
        }
        if (oldVersion < 6) {
          await db.execute(
              'ALTER TABLE preparaciones ADD COLUMN tempo_actual INTEGER');
          await db.execute(
              'ALTER TABLE preparaciones ADD COLUMN tempo_objetivo INTEGER');
        }
        if (oldVersion < 7) {
          await db
              .execute('ALTER TABLE objetivos ADD COLUMN estado_mental TEXT');
          await db.execute(
              'ALTER TABLE objetivos ADD COLUMN tiempo_minimo INTEGER NOT NULL DEFAULT 10');
          await db.execute(
              'ALTER TABLE objetivos ADD COLUMN tiempo_maximo INTEGER NOT NULL DEFAULT 25');
          await db.execute('ALTER TABLE tareas ADD COLUMN objetivo_id TEXT');
          await db
              .execute('ALTER TABLE tareas ADD COLUMN titulo_objetivo TEXT');
          await db.execute('ALTER TABLE tareas ADD COLUMN tipo_objetivo TEXT');
        }
      },
    );
  }

  /// Fase A del plan de auditoría: Problema, Patrón, Capacidad, Categoría,
  /// Profesor y Recomendación, más las tablas puente para las relaciones
  /// muchos-a-muchos de Patrón (con Elemento y con Problema).
  Future<void> _crearTablasFaseA(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS problemas (
        id TEXT PRIMARY KEY,
        descripcion TEXT NOT NULL,
        categoria TEXT NOT NULL,
        intensidad TEXT NOT NULL,
        estado TEXT NOT NULL,
        preparacion_id TEXT,
        segmento_id TEXT,
        primera_aparicion TEXT NOT NULL,
        ultima_aparicion TEXT,
        cantidad_sesiones INTEGER NOT NULL,
        soluciones TEXT NOT NULL,
        ejercicios_relacionados TEXT NOT NULL,
        FOREIGN KEY (preparacion_id) REFERENCES preparaciones(id),
        FOREIGN KEY (segmento_id) REFERENCES segmentos(id)
      );
    ''');
    // Patrones removed: not needed in simplified app.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS capacidades (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        progreso INTEGER NOT NULL,
        notas TEXT NOT NULL,
        creado_en TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        dias_semana TEXT NOT NULL,
        minutos_objetivo INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS profesores (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        contacto TEXT,
        notas TEXT NOT NULL,
        creado_en TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recomendaciones (
        id TEXT PRIMARY KEY,
        profesor_id TEXT NOT NULL,
        texto TEXT NOT NULL,
        fecha TEXT NOT NULL,
        estado TEXT NOT NULL,
        preparacion_id TEXT,
        segmento_id TEXT,
        FOREIGN KEY (profesor_id) REFERENCES profesores(id)
      );
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_problema_prep ON problemas(preparacion_id);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_recom_profesor ON recomendaciones(profesor_id);');
  }

  // ---------- Elementos ----------
  Future<void> insertElemento(Elemento e) async =>
      (await database).insert('elementos', e.toMap());

  Future<List<Elemento>> getElementos() async {
    final rows = await (await database).query('elementos', orderBy: 'nombre');
    return rows.map(Elemento.fromMap).toList();
  }

  Future<void> updateElemento(Elemento e) async => (await database)
      .update('elementos', e.toMap(), where: 'id = ?', whereArgs: [e.id]);

  Future<void> deleteElemento(String id) async {
    final db = await database;
    final preps = await db
        .query('preparaciones', where: 'elemento_id = ?', whereArgs: [id]);
    for (final prep in preps) {
      final prepId = prep['id'] as String;
      await deletePreparacion(prepId);
    }
    await db.delete('elementos', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Preparaciones ----------
  Future<void> insertPreparacion(Preparacion p) async =>
      (await database).insert('preparaciones', p.toMap());

  Future<void> updatePreparacion(Preparacion p) async => (await database)
      .update('preparaciones', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<List<Preparacion>> getPreparacionesActivas() async {
    final rows = await (await database).query('preparaciones',
        where: 'activa = 1', orderBy: 'ultima_practica ASC');
    return rows.map(Preparacion.fromMap).toList();
  }

  Future<List<Preparacion>> getTodasPreparaciones() async {
    final rows = await (await database)
        .query('preparaciones', orderBy: 'creado_en DESC');
    return rows.map(Preparacion.fromMap).toList();
  }

  Future<void> deletePreparacion(String id) async {
    final db = await database;
    await db.delete('segmentos', where: 'preparacion_id = ?', whereArgs: [id]);
    await db.delete('objetivos', where: 'preparacion_id = ?', whereArgs: [id]);
    await db.delete('notas', where: 'preparacion_id = ?', whereArgs: [id]);
    await db.delete('tareas', where: 'preparacion_id = ?', whereArgs: [id]);
    await db.delete('preparaciones', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Segmentos ----------
  Future<void> insertSegmento(Segmento s) async =>
      (await database).insert('segmentos', s.toMap());

  Future<void> updateSegmento(Segmento s) async => (await database)
      .update('segmentos', s.toMap(), where: 'id = ?', whereArgs: [s.id]);

  Future<void> deleteSegmento(String id) async =>
      (await database).delete('segmentos', where: 'id = ?', whereArgs: [id]);

  Future<List<Segmento>> getSegmentos(String preparacionId) async {
    final rows = await (await database).query('segmentos',
        where: 'preparacion_id = ?',
        whereArgs: [preparacionId],
        orderBy: 'prioridad DESC');
    return rows.map(Segmento.fromMap).toList();
  }

  Future<List<Segmento>> getTodosSegmentosActivos() async {
    final rows = await (await database).rawQuery('''
      SELECT s.* FROM segmentos s
      INNER JOIN preparaciones p ON p.id = s.preparacion_id
      WHERE p.activa = 1 AND s.estado != 'resuelto'
    ''');
    return rows.map(Segmento.fromMap).toList();
  }

  // ---------- Objetivos ----------
  Future<void> insertObjetivo(Objetivo o) async =>
      (await database).insert('objetivos', o.toMap());

  Future<void> updateObjetivo(Objetivo o) async => (await database)
      .update('objetivos', o.toMap(), where: 'id = ?', whereArgs: [o.id]);

  Future<List<Objetivo>> getObjetivos(String preparacionId) async {
    final rows = await (await database).query('objetivos',
        where: 'preparacion_id = ?', whereArgs: [preparacionId]);
    return rows.map(Objetivo.fromMap).toList();
  }

  Future<List<Objetivo>> getObjetivosPorSegmento(String segmentoId) async {
    final rows = await (await database)
        .query('objetivos', where: 'segmento_id = ?', whereArgs: [segmentoId]);
    return rows.map(Objetivo.fromMap).toList();
  }

  Future<Objetivo?> getObjetivoPorId(String id) async {
    final rows = await (await database)
        .query('objetivos', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Objetivo.fromMap(rows.first);
  }

  // ---------- Sesiones y tareas ----------
  Future<void> insertSesion(Sesion s) async =>
      (await database).insert('sesiones', s.toMap());

  Future<void> updateSesion(Sesion s) async => (await database)
      .update('sesiones', s.toMap(), where: 'id = ?', whereArgs: [s.id]);

  Future<void> insertTarea(Tarea t) async =>
      (await database).insert('tareas', t.toMap());

  Future<void> updateTarea(Tarea t) async => (await database)
      .update('tareas', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<List<Tarea>> getTareas(String sesionId) async {
    final rows = await (await database)
        .query('tareas', where: 'sesion_id = ?', whereArgs: [sesionId]);
    return rows.map(Tarea.fromMap).toList();
  }

  Future<List<Sesion>> getHistorial() async {
    final rows = await (await database).query('sesiones',
        where: "estado = 'finalizada'", orderBy: 'fecha DESC');
    return rows.map(Sesion.fromMap).toList();
  }

  Future<Sesion?> getSesionEnCurso() async {
    final rows = await (await database).query('sesiones',
        where: "estado != 'finalizada'", orderBy: 'fecha DESC', limit: 1);
    if (rows.isEmpty) return null;
    return Sesion.fromMap(rows.first);
  }

  // ---------- Notas / diario ----------
  Future<void> insertNota(Nota n) async =>
      (await database).insert('notas', n.toMap());

  Future<List<Nota>> getDiario() async {
    final rows = await (await database).query('notas', orderBy: 'fecha DESC');
    return rows.map(Nota.fromMap).toList();
  }

  Future<List<Nota>> getNotasPorPreparacion(String preparacionId) async {
    final rows = await (await database).query('notas',
        where: 'preparacion_id = ?',
        whereArgs: [preparacionId],
        orderBy: 'fecha DESC');
    return rows.map(Nota.fromMap).toList();
  }

  // ---------- Problemas ----------
  Future<void> insertProblema(Problema p) async =>
      (await database).insert('problemas', p.toMap());

  Future<void> updateProblema(Problema p) async => (await database)
      .update('problemas', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<void> deleteProblema(String id) async =>
      (await database).delete('problemas', where: 'id = ?', whereArgs: [id]);

  Future<List<Problema>> getProblemas({String? estado}) async {
    final rows = await (await database).query(
      'problemas',
      where: estado != null ? 'estado = ?' : null,
      whereArgs: estado != null ? [estado] : null,
      orderBy: 'primera_aparicion DESC',
    );
    return rows.map(Problema.fromMap).toList();
  }

  // Patrones removed: related helpers deleted.

  // ---------- Capacidades ----------
  Future<void> insertCapacidad(Capacidad c) async =>
      (await database).insert('capacidades', c.toMap());

  Future<void> updateCapacidad(Capacidad c) async => (await database)
      .update('capacidades', c.toMap(), where: 'id = ?', whereArgs: [c.id]);

  Future<void> deleteCapacidad(String id) async =>
      (await database).delete('capacidades', where: 'id = ?', whereArgs: [id]);

  Future<List<Capacidad>> getCapacidades() async {
    final rows = await (await database).query('capacidades', orderBy: 'nombre');
    return rows.map(Capacidad.fromMap).toList();
  }

  // ---------- Categorías ----------
  Future<void> insertCategoria(Categoria c) async =>
      (await database).insert('categorias', c.toMap());

  Future<void> updateCategoria(Categoria c) async => (await database)
      .update('categorias', c.toMap(), where: 'id = ?', whereArgs: [c.id]);

  Future<void> deleteCategoria(String id) async =>
      (await database).delete('categorias', where: 'id = ?', whereArgs: [id]);

  Future<List<Categoria>> getCategorias() async {
    final rows = await (await database).query('categorias', orderBy: 'nombre');
    return rows.map(Categoria.fromMap).toList();
  }

  // ---------- Profesores ----------
  Future<void> insertProfesor(Profesor p) async =>
      (await database).insert('profesores', p.toMap());

  Future<void> updateProfesor(Profesor p) async => (await database)
      .update('profesores', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<void> deleteProfesor(String id) async {
    final db = await database;
    await db
        .delete('recomendaciones', where: 'profesor_id = ?', whereArgs: [id]);
    await db.delete('profesores', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Profesor>> getProfesores() async {
    final rows = await (await database).query('profesores', orderBy: 'nombre');
    return rows.map(Profesor.fromMap).toList();
  }

  // ---------- Recomendaciones ----------
  Future<void> insertRecomendacion(Recomendacion r) async =>
      (await database).insert('recomendaciones', r.toMap());

  Future<void> updateRecomendacion(Recomendacion r) async => (await database)
      .update('recomendaciones', r.toMap(), where: 'id = ?', whereArgs: [r.id]);

  Future<void> deleteRecomendacion(String id) async => (await database)
      .delete('recomendaciones', where: 'id = ?', whereArgs: [id]);

  Future<List<Recomendacion>> getRecomendaciones(String profesorId) async {
    final rows = await (await database).query('recomendaciones',
        where: 'profesor_id = ?',
        whereArgs: [profesorId],
        orderBy: 'fecha DESC');
    return rows.map(Recomendacion.fromMap).toList();
  }
}
