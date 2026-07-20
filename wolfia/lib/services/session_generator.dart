import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';

const _diasAbrev = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];

/// Motor generador de sesiones.
///
/// Las "tareas" que arma una sesión son siempre Objetivos (de segmento o
/// de la preparación en sí) — nunca preparaciones/segmentos genéricos.
/// Reglas, en el orden que pidió el usuario:
/// - Se reparte el tiempo entre obra/ejercicio (70/30, ajustable si un
///   tipo no tiene candidatos).
/// - Prioridad de preparación: fecha límite próxima, prioridad manual,
///   categoría (¿hoy es día permitido?), estado, puntos (menos puntos =
///   más prioridad), días sin practicar.
/// - Los objetivos de segmento siempre se consideran primero; los
///   objetivos "per se" de la preparación sólo entran si NO quedan
///   objetivos de segmento pendientes en esa preparación.
/// - Dentro de eso: prioridad del objetivo y su último estado mental
///   registrado (cansado/frustrado empuja a repetirlo pronto).
/// - Nunca se asigna menos del tiempo mínimo de un objetivo, ni más que
///   su tiempo máximo (si lo tiene).
class SessionGenerator {
  final _uuid = const Uuid();
  final _db = WolfiaDb.instance;

  Future<Sesion> generar({required int minutosDisponibles}) async {
    final plan = await planificar(minutosDisponibles: minutosDisponibles);
    final sesion = plan['sesion'] as Sesion;
    final tareas = plan['tareas'] as List<Tarea>;
    await _db.insertSesion(sesion);
    for (final t in tareas) {
      await _db.insertTarea(t);
    }
    return sesion;
  }

  /// Arma el plan (sesión + tareas) sin necesariamente persistirlo.
  Future<Map<String, dynamic>> planificar(
      {required int minutosDisponibles}) async {
    final sesion = Sesion(
      id: _uuid.v4(),
      fecha: DateTime.now(),
      duracionPlaneada: minutosDisponibles,
      estado: 'generada',
    );

    final preparaciones = await _db.getPreparacionesActivas();
    if (preparaciones.isEmpty) {
      return {'sesion': sesion, 'tareas': <Tarea>[]};
    }

    final elementos = await _db.getElementos();
    final categorias = await _db.getCategorias();
    final hoyAbrev = _diasAbrev[DateTime.now().weekday - 1];

    final candidatosObra = <_Candidato>[];
    final candidatosEjercicio = <_Candidato>[];

    for (final prep in preparaciones) {
      Elemento? elemento;
      for (final e in elementos) {
        if (e.id == prep.elementoId) {
          elemento = e;
          break;
        }
      }
      if (elemento == null) continue;

      Categoria? categoria;
      if (prep.categoria != null) {
        for (final c in categorias) {
          if (c.nombre == prep.categoria) {
            categoria = c;
            break;
          }
        }
      }

      final scorePrep = _scorePreparacion(prep, categoria, hoyAbrev);
      final motivoPrep = _motivoPreparacion(prep, categoria, hoyAbrev);

      final segmentos = await _db.getSegmentos(prep.id);
      final segmentosActivos =
          segmentos.where((s) => s.estado != 'resuelto').toList();

      final objetivosDeSegmentoPendientes = <_Candidato>[];
      for (final seg in segmentosActivos) {
        final objs = await _db.getObjetivosPorSegmento(seg.id);
        for (final o in objs) {
          if (o.estado == 'cumplido' || o.estado == 'descartado') continue;
          final score = _scoreObjetivo(o, scorePrep);
          objetivosDeSegmentoPendientes.add(_Candidato(
            preparacion: prep,
            elemento: elemento,
            segmento: seg,
            objetivo: o,
            score: score,
            motivo: _motivoObjetivo(o, seg, motivoPrep),
          ));
        }
      }

      final destino =
          elemento.tipo == 'ejercicio' ? candidatosEjercicio : candidatosObra;

      if (objetivosDeSegmentoPendientes.isNotEmpty) {
        // Hay objetivos de segmento: los "per se" de la preparación quedan
        // afuera hasta que se terminen todos los de segmento.
        destino.addAll(objetivosDeSegmentoPendientes);
      } else {
        // Sin objetivos de segmento pendientes (o sin segmentos): entran
        // los objetivos "per se" de la preparación.
        final objetivosPrep = await _db.getObjetivos(prep.id);
        for (final o in objetivosPrep) {
          if (o.segmentoId != null) continue; // ya cubiertos arriba
          if (o.estado == 'cumplido' || o.estado == 'descartado') continue;
          final score = _scoreObjetivo(o, scorePrep);
          destino.add(_Candidato(
            preparacion: prep,
            elemento: elemento,
            segmento: null,
            objetivo: o,
            score: score,
            motivo: _motivoObjetivo(o, null, motivoPrep),
          ));
        }
      }
    }

    candidatosObra.sort((a, b) => b.score.compareTo(a.score));
    candidatosEjercicio.sort((a, b) => b.score.compareTo(a.score));

    // Reparto de tiempo por tipo de elemento (70% obra / 30% ejercicio,
    // ajustado si un tipo no tiene candidatos).
    int presupuestoObra;
    int presupuestoEjercicio;
    if (candidatosObra.isEmpty) {
      presupuestoObra = 0;
      presupuestoEjercicio = minutosDisponibles;
    } else if (candidatosEjercicio.isEmpty) {
      presupuestoObra = minutosDisponibles;
      presupuestoEjercicio = 0;
    } else {
      presupuestoObra = (minutosDisponibles * 0.7).round();
      presupuestoEjercicio = minutosDisponibles - presupuestoObra;
    }

    final usados = <_Candidato>{};
    final resultObra =
        _asignarPresupuesto(candidatosObra, presupuestoObra, usados);
    final resultEjercicio = _asignarPresupuesto(
        candidatosEjercicio, presupuestoEjercicio, usados);

    // Si sobró presupuesto de un lado y todavía hay candidatos pendientes
    // del otro, se lo pasamos para no desperdiciar tiempo disponible.
    final tareas = <Tarea>[
      ...resultObra.tareas(sesion, _uuid),
      ...resultEjercicio.tareas(sesion, _uuid),
    ];
    var restanteGlobal = resultObra.restante + resultEjercicio.restante;

    if (restanteGlobal > 0) {
      final pendientes = [
        ...candidatosObra.where((c) => !usados.contains(c)),
        ...candidatosEjercicio.where((c) => !usados.contains(c)),
      ]..sort((a, b) => b.score.compareTo(a.score));
      final extra = _asignarPresupuesto(pendientes, restanteGlobal, usados);
      tareas.addAll(extra.tareas(sesion, _uuid));
      restanteGlobal = extra.restante;
    }

    return {'sesion': sesion, 'tareas': tareas};
  }

  _AsignacionResultado _asignarPresupuesto(
      List<_Candidato> candidatos, int presupuesto, Set<_Candidato> usados) {
    var restante = presupuesto;
    final elegidos = <_Candidato, int>{};
    for (final c in candidatos) {
      if (usados.contains(c)) continue;
      if (restante < c.objetivo.tiempoMinimo) continue; // no forzar mínimos
      final tope = c.objetivo.tiempoMaximo ?? (c.objetivo.tiempoMinimo * 3);
      final minutos = restante < tope ? restante : tope;
      if (minutos < c.objetivo.tiempoMinimo) continue;
      elegidos[c] = minutos;
      usados.add(c);
      restante -= minutos;
    }
    return _AsignacionResultado(elegidos, restante);
  }

  double _scorePreparacion(
      Preparacion prep, Categoria? categoria, String hoyAbrev) {
    double score = 20;
    score += prep.prioridad * 10; // 1-5 -> 10-50

    if (prep.fechaObjetivo != null) {
      final dias = prep.fechaObjetivo!.difference(DateTime.now()).inDays;
      if (dias <= 0) {
        score += 60; // vencida o es hoy: máxima urgencia
      } else {
        score += (60 - dias).clamp(0, 60).toDouble();
      }
    }

    if (prep.estado == 'estudiando' || prep.estado == 'consolidando') {
      score += 8;
    }

    // Menos puntos acumulados = más prioridad (se la está dejando atrás).
    score += (100 - prep.puntos).clamp(0, 100) * 0.3;

    final diasSinPracticar = prep.ultimaPractica == null
        ? 999
        : DateTime.now().difference(prep.ultimaPractica!).inDays;
    score += diasSinPracticar.clamp(0, 30) * 1.2;

    if (categoria != null && categoria.diasList.isNotEmpty) {
      if (!categoria.diasList.contains(hoyAbrev)) {
        score -= 50; // hoy no es un día preferido para esta categoría
      } else {
        score += 10;
      }
    }

    return score;
  }

  double _scoreObjetivo(Objetivo o, double scorePrep) {
    double score = scorePrep;
    score += o.prioridad * 8; // 1-5 -> 8-40
    switch (o.estadoMental) {
      case 'cansado':
      case 'frustrado':
        score += 12; // conviene retomarlo pronto
        break;
      case 'dominado':
      case 'comodo':
        score -= 15; // ya viene bien, baja prioridad
        break;
      case 'motivado':
      case 'en_flujo':
        score += 4; // aprovechar el envión
        break;
    }
    return score;
  }

  String _motivoPreparacion(
      Preparacion prep, Categoria? categoria, String hoyAbrev) {
    final partes = <String>[];
    if (prep.fechaObjetivo != null) {
      final dias = prep.fechaObjetivo!.difference(DateTime.now()).inDays;
      if (dias <= 0) {
        partes.add('fecha límite vencida o es hoy');
      } else if (dias <= 14) {
        partes.add('fecha límite en $dias día${dias == 1 ? '' : 's'}');
      }
    }
    if (prep.prioridad >= 4) partes.add('prioridad alta');
    final dias = prep.ultimaPractica == null
        ? 999
        : DateTime.now().difference(prep.ultimaPractica!).inDays;
    if (dias >= 999) {
      partes.add('todavía no tiene sesiones');
    } else if (dias > 0) {
      partes.add('hace $dias día${dias == 1 ? '' : 's'} que no se practica');
    }
    if (categoria != null &&
        categoria.diasList.isNotEmpty &&
        categoria.diasList.contains(hoyAbrev)) {
      partes.add('hoy toca ${categoria.nombre}');
    }
    return partes.join(' · ');
  }

  String _motivoObjetivo(Objetivo o, Segmento? seg, String motivoPrep) {
    final partes = <String>[motivoPrep];
    if (o.prioridad >= 4) partes.add('objetivo prioritario');
    if (o.estadoMental == 'cansado' || o.estadoMental == 'frustrado') {
      partes.add('la última vez costó (${o.estadoMental}) — retomar');
    }
    return partes.where((p) => p.isNotEmpty).join(' · ');
  }
}

class _Candidato {
  final Preparacion preparacion;
  final Elemento elemento;
  final Segmento? segmento;
  final Objetivo objetivo;
  final double score;
  final String motivo;

  _Candidato({
    required this.preparacion,
    required this.elemento,
    required this.segmento,
    required this.objetivo,
    required this.score,
    required this.motivo,
  });
}

class _AsignacionResultado {
  final Map<_Candidato, int> elegidos;
  final int restante;
  _AsignacionResultado(this.elegidos, this.restante);

  List<Tarea> tareas(Sesion sesion, Uuid uuid) {
    return elegidos.entries
        .map((e) => Tarea(
              id: uuid.v4(),
              sesionId: sesion.id,
              preparacionId: e.key.preparacion.id,
              segmentoId: e.key.segmento?.id,
              objetivoId: e.key.objetivo.id,
              tituloPreparacion: e.key.preparacion.nombre,
              tituloSegmento: e.key.segmento?.nombre ?? e.key.objetivo.descripcion,
              minutosPlaneados: e.value,
              motivo: e.key.motivo,
            ))
        .toList();
  }
}
