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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE elementos (
            id TEXT PRIMARY KEY,
            nombre TEXT NOT NULL,
            tipo TEXT NOT NULL,
            compositor TEXT,
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
            estado TEXT NOT NULL,
            activa INTEGER NOT NULL,
            fecha_objetivo TEXT,
            puntos INTEGER NOT NULL,
            ultima_practica TEXT,
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
            titulo_preparacion TEXT NOT NULL,
            titulo_segmento TEXT,
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
        await db.execute('CREATE INDEX idx_prep_activa ON preparaciones(activa);');
        await db.execute('CREATE INDEX idx_seg_prep ON segmentos(preparacion_id);');
        await db.execute('CREATE INDEX idx_tarea_sesion ON tareas(sesion_id);');
        await _crearTablasFaseA(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _crearTablasFaseA(db);
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patrones (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        familia TEXT NOT NULL,
        creado_en TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patron_elementos (
        patron_id TEXT NOT NULL,
        elemento_id TEXT NOT NULL,
        PRIMARY KEY (patron_id, elemento_id),
        FOREIGN KEY (patron_id) REFERENCES patrones(id),
        FOREIGN KEY (elemento_id) REFERENCES elementos(id)
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patron_problemas (
        patron_id TEXT NOT NULL,
        problema_id TEXT NOT NULL,
        PRIMARY KEY (patron_id, problema_id),
        FOREIGN KEY (patron_id) REFERENCES patrones(id),
        FOREIGN KEY (problema_id) REFERENCES problemas(id)
      );
    ''');
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_problema_prep ON problemas(preparacion_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recom_profesor ON recomendaciones(profesor_id);');
  }

  // ---------- Elementos ----------
  Future<void> insertElemento(Elemento e) async =>
      (await database).insert('elementos', e.toMap());

  Future<List<Elemento>> getElementos() async {
    final rows = await (await database).query('elementos', orderBy: 'nombre');
    return rows.map(Elemento.fromMap).toList();
  }

  // ---------- Preparaciones ----------
  Future<void> insertPreparacion(Preparacion p) async =>
      (await database).insert('preparaciones', p.toMap());

  Future<void> updatePreparacion(Preparacion p) async => (await database)
      .update('preparaciones', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<List<Preparacion>> getPreparacionesActivas() async {
    final rows = await (await database)
        .query('preparaciones', where: 'activa = 1', orderBy: 'ultima_practica ASC');
    return rows.map(Preparacion.fromMap).toList();
  }

  Future<List<Preparacion>> getTodasPreparaciones() async {
    final rows = await (await database).query('preparaciones', orderBy: 'creado_en DESC');
    return rows.map(Preparacion.fromMap).toList();
  }

  // ---------- Segmentos ----------
  Future<void> insertSegmento(Segmento s) async =>
      (await database).insert('segmentos', s.toMap());

  Future<void> updateSegmento(Segmento s) async => (await database)
      .update('segmentos', s.toMap(), where: 'id = ?', whereArgs: [s.id]);

  Future<List<Segmento>> getSegmentos(String preparacionId) async {
    final rows = await (await database).query('segmentos',
        where: 'preparacion_id = ?', whereArgs: [preparacionId], orderBy: 'prioridad DESC');
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
    final rows = await (await database)
        .query('sesiones', where: "estado = 'finalizada'", orderBy: 'fecha DESC');
    return rows.map(Sesion.fromMap).toList();
  }

  Future<Sesion?> getSesionEnCurso() async {
    final rows = await (await database)
        .query('sesiones', where: "estado != 'finalizada'", orderBy: 'fecha DESC', limit: 1);
    if (rows.isEmpty) return null;
    return Sesion.fromMap(rows.first);
  }

  // ---------- Notas / diario ----------
  Future<void> insertNota(Nota n) async => (await database).insert('notas', n.toMap());

  Future<List<Nota>> getDiario() async {
    final rows = await (await database).query('notas', orderBy: 'fecha DESC');
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

  // ---------- Patrones ----------
  Future<void> insertPatron(Patron p) async =>
      (await database).insert('patrones', p.toMap());

  Future<void> updatePatron(Patron p) async => (await database)
      .update('patrones', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<void> deletePatron(String id) async {
    final db = await database;
    await db.delete('patron_elementos', where: 'patron_id = ?', whereArgs: [id]);
    await db.delete('patron_problemas', where: 'patron_id = ?', whereArgs: [id]);
    await db.delete('patrones', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Patron>> getPatrones() async {
    final rows = await (await database).query('patrones', orderBy: 'nombre');
    return rows.map(Patron.fromMap).toList();
  }

  Future<void> vincularPatronElemento(String patronId, String elementoId) async =>
      (await database).insert('patron_elementos',
          {'patron_id': patronId, 'elemento_id': elementoId},
          conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> desvincularPatronElemento(String patronId, String elementoId) async =>
      (await database).delete('patron_elementos',
          where: 'patron_id = ? AND elemento_id = ?', whereArgs: [patronId, elementoId]);

  Future<List<Elemento>> getElementosDePatron(String patronId) async {
    final rows = await (await database).rawQuery('''
      SELECT e.* FROM elementos e
      INNER JOIN patron_elementos pe ON pe.elemento_id = e.id
      WHERE pe.patron_id = ?
    ''', [patronId]);
    return rows.map(Elemento.fromMap).toList();
  }

  Future<void> vincularPatronProblema(String patronId, String problemaId) async =>
      (await database).insert('patron_problemas',
          {'patron_id': patronId, 'problema_id': problemaId},
          conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> desvincularPatronProblema(String patronId, String problemaId) async =>
      (await database).delete('patron_problemas',
          where: 'patron_id = ? AND problema_id = ?', whereArgs: [patronId, problemaId]);

  Future<List<Problema>> getProblemasDePatron(String patronId) async {
    final rows = await (await database).rawQuery('''
      SELECT p.* FROM problemas p
      INNER JOIN patron_problemas pp ON pp.problema_id = p.id
      WHERE pp.patron_id = ?
    ''', [patronId]);
    return rows.map(Problema.fromMap).toList();
  }

  /// Detecta patrones cuyos problemas vinculados aparecen en más de un
  /// elemento distinto (vía preparación) — es decir, el mismo problema
  /// "se repite entre varias obras".
  Future<Map<String, int>> contarElementosDistintosPorPatron() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT pp.patron_id AS patron_id, COUNT(DISTINCT prep.elemento_id) AS n
      FROM patron_problemas pp
      INNER JOIN problemas pr ON pr.id = pp.problema_id
      INNER JOIN preparaciones prep ON prep.id = pr.preparacion_id
      GROUP BY pp.patron_id
    ''');
    return {for (final r in rows) r['patron_id'] as String: r['n'] as int};
  }

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
    await db.delete('recomendaciones', where: 'profesor_id = ?', whereArgs: [id]);
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

  Future<void> deleteRecomendacion(String id) async =>
      (await database).delete('recomendaciones', where: 'id = ?', whereArgs: [id]);

  Future<List<Recomendacion>> getRecomendaciones(String profesorId) async {
    final rows = await (await database).query('recomendaciones',
        where: 'profesor_id = ?', whereArgs: [profesorId], orderBy: 'fecha DESC');
    return rows.map(Recomendacion.fromMap).toList();
  }
}
