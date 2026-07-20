/// Modelos de dominio de Wolfia.
/// Simplificación deliberada del SDD original: un pianista usando esto
/// solo no necesita event sourcing, CQRS ni sync multi-dispositivo.
/// Sí conservamos la idea central: Elemento -> Preparación -> Segmento ->
/// Objetivo, y la Sesión como unidad que ejecuta Tareas.

class Elemento {
  final String id;
  String nombre;
  String tipo; // 'obra' | 'ejercicio'
  String? compositor;
  int? compases;
  String categoria;
  String estado; // pendiente/leyendo/estudiando/consolidando/lista/archivada
  String notas;
  DateTime creadoEn;

  Elemento({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.compositor,
    this.compases,
    this.categoria = 'General',
    this.estado = 'pendiente',
    this.notas = '',
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
        'compositor': compositor,
        'categoria': categoria,
        'compases': compases,
        'estado': estado,
        'notas': notas,
        'creado_en': creadoEn.toIso8601String(),
      };

  factory Elemento.fromMap(Map<String, dynamic> m) => Elemento(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        tipo: m['tipo'] as String,
        compositor: m['compositor'] as String?,
        compases: m['compases'] as int?,
        categoria: m['categoria'] as String? ?? 'General',
        estado: m['estado'] as String? ?? 'pendiente',
        notas: m['notas'] as String? ?? '',
        creadoEn: DateTime.parse(m['creado_en'] as String),
      );
}

/// Una Preparación es "un proceso de estudio" sobre un Elemento
/// (examen 2026, recital 2028, etc). Es lo que realmente vive activo.
class Preparacion {
  final String id;
  final String elementoId;
  String nombre;
  String? objetivoPrincipal;
  String estado; // pendiente/leyendo/estudiando/consolidando/lista/finalizada
  String? categoria;
  bool activa;
  DateTime? fechaObjetivo;
  int puntos;
  int prioridad; // 1-5
  int tiempoInvertido; // minutos
  int sesionesCount;
  String? profesorId;
  DateTime? ultimaPractica;
  int? tempoActual;
  int? tempoObjetivo;
  DateTime creadoEn;

  Preparacion({
    required this.id,
    required this.elementoId,
    required this.nombre,
    this.objetivoPrincipal,
    this.categoria,
    this.estado = 'pendiente',
    this.activa = true,
    this.fechaObjetivo,
    this.puntos = 0,
    this.prioridad = 3,
    this.tiempoInvertido = 0,
    this.sesionesCount = 0,
    this.profesorId,
    this.ultimaPractica,
    this.tempoActual,
    this.tempoObjetivo,
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'elemento_id': elementoId,
        'nombre': nombre,
        'objetivo_principal': objetivoPrincipal,
        'estado': estado,
        'categoria': categoria,
        'activa': activa ? 1 : 0,
        'fecha_objetivo': fechaObjetivo?.toIso8601String(),
        'puntos': puntos,
        'prioridad': prioridad,
        'tiempo_invertido': tiempoInvertido,
        'sesiones_count': sesionesCount,
        'profesor_id': profesorId,
        'ultima_practica': ultimaPractica?.toIso8601String(),
        'tempo_actual': tempoActual,
        'tempo_objetivo': tempoObjetivo,
        'creado_en': creadoEn.toIso8601String(),
      };

  factory Preparacion.fromMap(Map<String, dynamic> m) => Preparacion(
        id: m['id'] as String,
        elementoId: m['elemento_id'] as String,
        nombre: m['nombre'] as String,
        objetivoPrincipal: m['objetivo_principal'] as String?,
        categoria: m['categoria'] as String?,
        estado: m['estado'] as String? ?? 'pendiente',
        activa: (m['activa'] as int? ?? 1) == 1,
        fechaObjetivo: m['fecha_objetivo'] != null
            ? DateTime.parse(m['fecha_objetivo'] as String)
            : null,
        puntos: m['puntos'] as int? ?? 0,
        prioridad: m['prioridad'] as int? ?? 3,
        tiempoInvertido: m['tiempo_invertido'] as int? ?? 0,
        sesionesCount: m['sesiones_count'] as int? ?? 0,
        profesorId: m['profesor_id'] as String?,
        ultimaPractica: m['ultima_practica'] != null
            ? DateTime.parse(m['ultima_practica'] as String)
            : null,
        tempoActual: m['tempo_actual'] as int?,
        tempoObjetivo: m['tempo_objetivo'] as int?,
        creadoEn: DateTime.parse(m['creado_en'] as String),
      );
}

class Segmento {
  final String id;
  final String preparacionId;
  String nombre;
  int prioridad; // 1 (baja) a 5 (crítica)
  String estado; // pendiente/activo/consolidando/resuelto
  int? tempoActual;
  int? tempoObjetivo;
  int? compasInicio;
  int? compasFin;
  DateTime? ultimaPractica;
  String notas;

  Segmento({
    required this.id,
    required this.preparacionId,
    required this.nombre,
    this.prioridad = 3,
    this.estado = 'pendiente',
    this.tempoActual,
    this.tempoObjetivo,
    this.compasInicio,
    this.compasFin,
    this.ultimaPractica,
    this.notas = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'preparacion_id': preparacionId,
        'nombre': nombre,
        'prioridad': prioridad,
        'estado': estado,
        'tempo_actual': tempoActual,
        'tempo_objetivo': tempoObjetivo,
        'ultima_practica': ultimaPractica?.toIso8601String(),
        'compas_inicio': compasInicio,
        'compas_fin': compasFin,
        'notas': notas,
      };

  factory Segmento.fromMap(Map<String, dynamic> m) => Segmento(
        id: m['id'] as String,
        preparacionId: m['preparacion_id'] as String,
        nombre: m['nombre'] as String,
        prioridad: m['prioridad'] as int? ?? 3,
        estado: m['estado'] as String? ?? 'pendiente',
        tempoActual: m['tempo_actual'] as int?,
        tempoObjetivo: m['tempo_objetivo'] as int?,
        compasInicio: m['compas_inicio'] as int?,
        compasFin: m['compas_fin'] as int?,
        ultimaPractica: m['ultima_practica'] != null
            ? DateTime.parse(m['ultima_practica'] as String)
            : null,
        notas: m['notas'] as String? ?? '',
      );

  int diasSinPracticar() {
    if (ultimaPractica == null) return 999;
    return DateTime.now().difference(ultimaPractica!).inDays;
  }
}

class Objetivo {
  final String id;
  final String preparacionId;
  final String? segmentoId;
  String descripcion;
  String estado; // pendiente/en_progreso/cumplido/descartado
  int prioridad; // 1-5, usada por el generador de sesiones
  int puntos; // acumulados
  int puntosPorMinuto; // puntos asignados por minuto trabajado
  int tiempoMinimo; // minutos, obligatorio: el generador nunca asigna menos
  int? tiempoMaximo; // minutos, opcional: el generador nunca asigna más
  String recomendaciones; // texto libre
  String? estadoMental; // motivado/comodo/cansado/frustrado/en_flujo... lo completa el músico al cerrar la tarea

  Objetivo({
    required this.id,
    required this.preparacionId,
    this.segmentoId,
    required this.descripcion,
    this.estado = 'pendiente',
    this.prioridad = 3,
    this.puntos = 0,
    this.puntosPorMinuto = 1,
    this.tiempoMinimo = 10,
    this.tiempoMaximo,
    this.recomendaciones = '',
    this.estadoMental,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'preparacion_id': preparacionId,
        'segmento_id': segmentoId,
        'descripcion': descripcion,
        'estado': estado,
        'prioridad': prioridad,
        'puntos': puntos,
        'puntos_por_minuto': puntosPorMinuto,
        'tiempo_minimo': tiempoMinimo,
        'tiempo_maximo': tiempoMaximo,
        'recomendaciones': recomendaciones,
        'estado_mental': estadoMental,
      };

  factory Objetivo.fromMap(Map<String, dynamic> m) => Objetivo(
        id: m['id'] as String,
        preparacionId: m['preparacion_id'] as String,
        segmentoId: m['segmento_id'] as String?,
        descripcion: m['descripcion'] as String,
        estado: m['estado'] as String? ?? 'pendiente',
        prioridad: m['prioridad'] as int? ?? 3,
        puntos: m['puntos'] as int? ?? 0,
        puntosPorMinuto: m['puntos_por_minuto'] as int? ?? 1,
        tiempoMinimo: m['tiempo_minimo'] as int? ?? 10,
        tiempoMaximo: m['tiempo_maximo'] as int?,
        recomendaciones: m['recomendaciones'] as String? ?? '',
        estadoMental: m['estado_mental'] as String?,
      );
}

class Sesion {
  final String id;
  DateTime fecha;
  int duracionPlaneada; // minutos
  int? duracionReal;
  String estado; // generada/en_curso/finalizada
  String notas;

  Sesion({
    required this.id,
    required this.fecha,
    required this.duracionPlaneada,
    this.duracionReal,
    this.estado = 'generada',
    this.notas = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'fecha': fecha.toIso8601String(),
        'duracion_planeada': duracionPlaneada,
        'duracion_real': duracionReal,
        'estado': estado,
        'notas': notas,
      };

  factory Sesion.fromMap(Map<String, dynamic> m) => Sesion(
        id: m['id'] as String,
        fecha: DateTime.parse(m['fecha'] as String),
        duracionPlaneada: m['duracion_planeada'] as int,
        duracionReal: m['duracion_real'] as int?,
        estado: m['estado'] as String? ?? 'generada',
        notas: m['notas'] as String? ?? '',
      );
}

class Tarea {
  final String id;
  final String sesionId;
  final String preparacionId;
  final String? segmentoId;
  final String? objetivoId;
  final String tituloPreparacion;
  final String? tituloSegmento;
  int minutosPlaneados;
  int? minutosReales;
  bool completada;
  String motivo; // por qué el generador eligió esta tarea
  String? resultado;

  Tarea({
    required this.id,
    required this.sesionId,
    required this.preparacionId,
    this.segmentoId,
    this.objetivoId,
    required this.tituloPreparacion,
    this.tituloSegmento,
    required this.minutosPlaneados,
    this.minutosReales,
    this.completada = false,
    this.motivo = '',
    this.resultado,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sesion_id': sesionId,
        'preparacion_id': preparacionId,
        'segmento_id': segmentoId,
        'objetivo_id': objetivoId,
        'titulo_preparacion': tituloPreparacion,
        'titulo_segmento': tituloSegmento,
        'minutos_planeados': minutosPlaneados,
        'minutos_reales': minutosReales,
        'completada': completada ? 1 : 0,
        'motivo': motivo,
        'resultado': resultado,
      };

  factory Tarea.fromMap(Map<String, dynamic> m) => Tarea(
        id: m['id'] as String,
        sesionId: m['sesion_id'] as String,
        preparacionId: m['preparacion_id'] as String,
        segmentoId: m['segmento_id'] as String?,
        objetivoId: m['objetivo_id'] as String?,
        tituloPreparacion: m['titulo_preparacion'] as String,
        tituloSegmento: m['titulo_segmento'] as String?,
        minutosPlaneados: m['minutos_planeados'] as int,
        minutosReales: m['minutos_reales'] as int?,
        completada: (m['completada'] as int? ?? 0) == 1,
        motivo: m['motivo'] as String? ?? '',
        resultado: m['resultado'] as String?,
      );
}

/// Nota rápida / entrada de diario. Puede o no estar ligada a algo.
class Nota {
  final String id;
  String contenido;
  String? preparacionId;
  String? segmentoId;
  String? sesionId;
  DateTime fecha;

  Nota({
    required this.id,
    required this.contenido,
    this.preparacionId,
    this.segmentoId,
    this.sesionId,
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'contenido': contenido,
        'preparacion_id': preparacionId,
        'segmento_id': segmentoId,
        'sesion_id': sesionId,
        'fecha': fecha.toIso8601String(),
      };

  factory Nota.fromMap(Map<String, dynamic> m) => Nota(
        id: m['id'] as String,
        contenido: m['contenido'] as String,
        preparacionId: m['preparacion_id'] as String?,
        segmentoId: m['segmento_id'] as String?,
        sesionId: m['sesion_id'] as String?,
        fecha: DateTime.parse(m['fecha'] as String),
      );
}

// ---------------------------------------------------------------------------
// Fase A del plan de auditoría: núcleo de dominio nuevo.
// Problema, Patrón, Capacidad, Categoría (con regla de calendario simple),
// Profesor y Recomendación. Todavía no están conectados al generador de
// sesiones ni a las pantallas existentes (eso es Fase C) — por ahora son
// modelos + persistencia + CRUD, que es "dónde enganchar" el resto.
// ---------------------------------------------------------------------------

/// Dificultad técnica/musical concreta y recurrente (no un simple checkbox).
class Problema {
  final String id;
  String descripcion;
  String
      categoria; // tecnica/musicalidad/memoria/lectura/interpretacion/postura/sonido/ritmo/pedal/digitacion
  String intensidad; // leve/media/alta/critica
  String estado; // activo/en_progreso/resuelto
  String? preparacionId;
  String? segmentoId;
  DateTime primeraAparicion;
  DateTime? ultimaAparicion;
  int cantidadSesiones;
  String soluciones; // texto libre: qué se probó / qué funcionó
  String
      ejerciciosRelacionados; // texto libre por ahora (sin banco de ejercicios todavía)

  Problema({
    required this.id,
    required this.descripcion,
    this.categoria = 'tecnica',
    this.intensidad = 'media',
    this.estado = 'activo',
    this.preparacionId,
    this.segmentoId,
    DateTime? primeraAparicion,
    this.ultimaAparicion,
    this.cantidadSesiones = 0,
    this.soluciones = '',
    this.ejerciciosRelacionados = '',
  }) : primeraAparicion = primeraAparicion ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'descripcion': descripcion,
        'categoria': categoria,
        'intensidad': intensidad,
        'estado': estado,
        'preparacion_id': preparacionId,
        'segmento_id': segmentoId,
        'primera_aparicion': primeraAparicion.toIso8601String(),
        'ultima_aparicion': ultimaAparicion?.toIso8601String(),
        'cantidad_sesiones': cantidadSesiones,
        'soluciones': soluciones,
        'ejercicios_relacionados': ejerciciosRelacionados,
      };

  factory Problema.fromMap(Map<String, dynamic> m) => Problema(
        id: m['id'] as String,
        descripcion: m['descripcion'] as String,
        categoria: m['categoria'] as String? ?? 'tecnica',
        intensidad: m['intensidad'] as String? ?? 'media',
        estado: m['estado'] as String? ?? 'activo',
        preparacionId: m['preparacion_id'] as String?,
        segmentoId: m['segmento_id'] as String?,
        primeraAparicion: DateTime.parse(m['primera_aparicion'] as String),
        ultimaAparicion: m['ultima_aparicion'] != null
            ? DateTime.parse(m['ultima_aparicion'] as String)
            : null,
        cantidadSesiones: m['cantidad_sesiones'] as int? ?? 0,
        soluciones: m['soluciones'] as String? ?? '',
        ejerciciosRelacionados: m['ejercicios_relacionados'] as String? ?? '',
      );
}

/// Manifestación técnica recurrente ENTRE obras (trinos, octavas, terceras,
/// polirritmias...). Distinto de Problema: un Patrón agrupa problemas que se
/// repiten en distintos elementos ("familia de patrones").
// Patron model removed: not used in simplified app.

/// Lo que realmente crece en el pianista (lectura, control rítmico, control
/// del sonido...). Se alimenta manualmente por ahora de patrones/problemas/
/// ejercicios resueltos; la alimentación automática es de una fase futura.
class Capacidad {
  final String id;
  String nombre;
  String descripcion;
  int progreso; // 0-100, autoevaluación manual por ahora
  String notas;
  DateTime creadoEn;

  Capacidad({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.progreso = 0,
    this.notas = '',
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'progreso': progreso,
        'notas': notas,
        'creado_en': creadoEn.toIso8601String(),
      };

  factory Capacidad.fromMap(Map<String, dynamic> m) => Capacidad(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        descripcion: m['descripcion'] as String? ?? '',
        progreso: m['progreso'] as int? ?? 0,
        notas: m['notas'] as String? ?? '',
        creadoEn: DateTime.parse(m['creado_en'] as String),
      );
}

/// Entidad Categoría con regla de distribución de tiempo/calendario simple
/// (días de la semana + minutos objetivo). Hoy Elemento.categoria sigue
/// siendo texto libre; conectar el generador de sesiones a esto es Fase C.
class Categoria {
  final String id;
  String nombre;
  String colorHex; // ej '#C9A84C'
  String diasSemana; // csv: 'lun,mar,mie,jue,vie,sab,dom'
  int minutosObjetivo; // minutos objetivo por semana

  Categoria({
    required this.id,
    required this.nombre,
    this.colorHex = '#C9A84C',
    this.diasSemana = 'lun,mar,mie,jue,vie,sab,dom',
    this.minutosObjetivo = 0,
  });

  List<String> get diasList =>
      diasSemana.split(',').where((d) => d.trim().isNotEmpty).toList();

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'color_hex': colorHex,
        'dias_semana': diasSemana,
        'minutos_objetivo': minutosObjetivo,
      };

  factory Categoria.fromMap(Map<String, dynamic> m) => Categoria(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        colorHex: m['color_hex'] as String? ?? '#C9A84C',
        diasSemana:
            m['dias_semana'] as String? ?? 'lun,mar,mie,jue,vie,sab,dom',
        minutosObjetivo: m['minutos_objetivo'] as int? ?? 0,
      );
}

class Profesor {
  final String id;
  String nombre;
  String? contacto;
  String notas;
  DateTime creadoEn;

  Profesor({
    required this.id,
    required this.nombre,
    this.contacto,
    this.notas = '',
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'contacto': contacto,
        'notas': notas,
        'creado_en': creadoEn.toIso8601String(),
      };

  factory Profesor.fromMap(Map<String, dynamic> m) => Profesor(
        id: m['id'] as String,
        nombre: m['nombre'] as String,
        contacto: m['contacto'] as String?,
        notas: m['notas'] as String? ?? '',
        creadoEn: DateTime.parse(m['creado_en'] as String),
      );
}

/// Recomendación del profesor como entidad propia (no una nota suelta),
/// vinculable opcionalmente a una preparación o segmento.
class Recomendacion {
  final String id;
  final String profesorId;
  String texto;
  DateTime fecha;
  String estado; // pendiente/aplicada/descartada
  String? preparacionId;
  String? segmentoId;

  Recomendacion({
    required this.id,
    required this.profesorId,
    required this.texto,
    DateTime? fecha,
    this.estado = 'pendiente',
    this.preparacionId,
    this.segmentoId,
  }) : fecha = fecha ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'profesor_id': profesorId,
        'texto': texto,
        'fecha': fecha.toIso8601String(),
        'estado': estado,
        'preparacion_id': preparacionId,
        'segmento_id': segmentoId,
      };

  factory Recomendacion.fromMap(Map<String, dynamic> m) => Recomendacion(
        id: m['id'] as String,
        profesorId: m['profesor_id'] as String,
        texto: m['texto'] as String,
        fecha: DateTime.parse(m['fecha'] as String),
        estado: m['estado'] as String? ?? 'pendiente',
        preparacionId: m['preparacion_id'] as String?,
        segmentoId: m['segmento_id'] as String?,
      );
}
