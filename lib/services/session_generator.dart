import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';

/// Generador de sesiones orientado a objetivos reales.
/// Prioriza objetivos de segmento cuando existen, y sólo incorpora objetivos
/// "per se" de la preparación cuando no hay objetivos pendientes de segmento.
class SessionGenerator {
  final _uuid = const Uuid();
  final _db = WolfiaDb.instance;

  Future<Sesion> generar({required int minutosDisponibles}) async {
    final plan = await planificar(minutosDisponibles: minutosDisponibles);
    final sesion = plan['sesion'] as Sesion;
    await _db.insertSesion(sesion);
    for (final tarea in plan['tareas'] as List<Tarea>) {
      await _db.insertTarea(Tarea(
        id: tarea.id,
        sesionId: sesion.id,
        preparacionId: tarea.preparacionId,
        segmentoId: tarea.segmentoId,
        objetivoId: tarea.objetivoId,
        tituloPreparacion: tarea.tituloPreparacion,
        tituloSegmento: tarea.tituloSegmento,
        tituloObjetivo: tarea.tituloObjetivo,
        tipoObjetivo: tarea.tipoObjetivo,
        minutosPlaneados: tarea.minutosPlaneados,
        motivo: tarea.motivo,
      ));
    }
    return sesion;
  }

  /// Planifica una sesión y devuelve la estructura (sesión + tareas) sin
  /// persistirla en la base de datos — útil para previsualizar el plan.
  Future<Map<String, dynamic>> planificar(
      {required int minutosDisponibles}) async {
    final preparaciones = await _db.getPreparacionesActivas();
    final segmentos = await _db.getTodosSegmentosActivos();
    final categorias = await _db.getCategorias();
    final elementos = await _db.getElementos();

    if (preparaciones.isEmpty) {
      final sesion = Sesion(
        id: _uuid.v4(),
        fecha: DateTime.now(),
        duracionPlaneada: minutosDisponibles,
        estado: 'generada',
      );
      return {'sesion': sesion, 'tareas': <Tarea>[]};
    }

    final tareas = <Tarea>[];
    int restante = minutosDisponibles;
    final sesion = Sesion(
      id: _uuid.v4(),
      fecha: DateTime.now(),
      duracionPlaneada: minutosDisponibles,
      estado: 'generada',
    );

    for (final prep in preparaciones) {
      final segsDePrep =
          segmentos.where((s) => s.preparacionId == prep.id).toList();
      final objetivos = await _db.getObjetivos(prep.id);
      final objetivosPendientes = objetivos
          .where((o) => o.estado != 'cumplido' && o.estado != 'descartado')
          .toList();

      final objetivosSegmento = objetivosPendientes
          .where((o) => o.segmentoId != null)
          .toList();
      final objetivosPrep = objetivosPendientes
          .where((o) => o.segmentoId == null)
          .toList();

      if (objetivosSegmento.isNotEmpty) {
        final candidatos = <_CandidatoObjetivo>[];
        for (final seg in segsDePrep) {
          final objs = objetivosSegmento
              .where((o) => o.segmentoId == seg.id)
              .toList();
          if (objs.isEmpty) continue;
          for (final obj in objs) {
            final score = _scoreObjetivo(
              prep: prep,
              seg: seg,
              obj: obj,
              categorias: categorias,
              elementos: elementos,
            );
            candidatos.add(_CandidatoObjetivo(
              preparacion: prep,
              segmento: seg,
              objetivo: obj,
              score: score,
              motivo: _motivoObjetivo(prep: prep, seg: seg, obj: obj),
            ));
          }
        }
        candidatos.sort((a, b) => b.score.compareTo(a.score));
        for (final c in candidatos) {
          if (restante < c.objetivo.tiempoMinimo) break;
          final minutos = asignarDuracionObjetivo(
            minutosDisponibles: restante,
            tiempoMinimo: c.objetivo.tiempoMinimo,
            tiempoMaximo: c.objetivo.tiempoMaximo,
          );
          if (minutos < c.objetivo.tiempoMinimo) break;
          final tarea = Tarea(
            id: _uuid.v4(),
            sesionId: sesion.id,
            preparacionId: prep.id,
            segmentoId: segsDePrep.isNotEmpty ? c.segmento?.id : null,
            objetivoId: c.objetivo.id,
            tituloPreparacion: prep.nombre,
            tituloSegmento: c.segmento?.nombre,
            tituloObjetivo: c.objetivo.descripcion,
            tipoObjetivo: 'segmento',
            minutosPlaneados: minutos,
            motivo: c.motivo,
          );
          tareas.add(tarea);
          restante -= minutos;
          if (restante <= 0) break;
        }
      } else if (objetivosPrep.isNotEmpty) {
        final candidatos = <_CandidatoObjetivo>[];
        for (final obj in objetivosPrep) {
          final score = _scoreObjetivo(
            prep: prep,
            seg: null,
            obj: obj,
            categorias: categorias,
            elementos: elementos,
          );
          candidatos.add(_CandidatoObjetivo(
            preparacion: prep,
            segmento: null,
            objetivo: obj,
            score: score,
            motivo: _motivoObjetivo(prep: prep, seg: null, obj: obj),
          ));
        }
        candidatos.sort((a, b) => b.score.compareTo(a.score));
        for (final c in candidatos) {
          if (restante < c.objetivo.tiempoMinimo) break;
          final minutos = asignarDuracionObjetivo(
            minutosDisponibles: restante,
            tiempoMinimo: c.objetivo.tiempoMinimo,
            tiempoMaximo: c.objetivo.tiempoMaximo,
          );
          if (minutos < c.objetivo.tiempoMinimo) break;
          final tarea = Tarea(
            id: _uuid.v4(),
            sesionId: sesion.id,
            preparacionId: prep.id,
            segmentoId: null,
            objetivoId: c.objetivo.id,
            tituloPreparacion: prep.nombre,
            tituloSegmento: null,
            tituloObjetivo: c.objetivo.descripcion,
            tipoObjetivo: 'preparacion',
            minutosPlaneados: minutos,
            motivo: c.motivo,
          );
          tareas.add(tarea);
          restante -= minutos;
          if (restante <= 0) break;
        }
      }
    }

    return {'sesion': sesion, 'tareas': tareas};
  }

  int asignarDuracionObjetivo({
    required int minutosDisponibles,
    required int tiempoMinimo,
    required int tiempoMaximo,
  }) {
    if (minutosDisponibles <= tiempoMinimo) return minutosDisponibles;
    final maxPermitido = tiempoMaximo.clamp(tiempoMinimo, minutosDisponibles);
    return maxPermitido;
  }

  double _scoreObjetivo({
    required Preparacion prep,
    required Segmento? seg,
    required Objetivo obj,
    required List<Categoria> categorias,
    required List<Elemento> elementos,
  }) {
    final diasPrep = prep.ultimaPractica == null
        ? 999
        : DateTime.now().difference(prep.ultimaPractica!).inDays;
    final diasSeg = seg?.diasSinPracticar() ?? diasPrep;
    final dias = seg == null ? diasPrep : diasSeg;
    final fechaLimite = prep.fechaObjetivo;
    final diasHastaLimite = fechaLimite == null
        ? 999
        : fechaLimite.difference(DateTime.now()).inDays.clamp(0, 365);
    final categoria = prep.categoria ?? '';
    final elemento = elementos.firstWhere(
      (e) => e.id == prep.elementoId,
      orElse: () => Elemento(id: '', nombre: '', tipo: 'ejercicio'),
    );
    final estadoMental = obj.estadoMental ?? 'neutral';
    final categoriaPermiteHoy = _categoriaPermiteHoy(categorias, prep.categoria);
    var score = 100.0;
    score += (seg?.prioridad ?? prep.prioridad) * 8;
    score += dias.clamp(0, 60) * 1.2;
    score += (obj.prioridad * 7);
    score += (obj.puntos == 0 ? 15 : 0);
    score += (obj.puntos < 10 ? 10 : 0);
    score += (diasHastaLimite <= 7 ? 25 : (diasHastaLimite <= 21 ? 12 : 0));
    score += (categoria.isNotEmpty ? 3 : 0);
    score += categoriaPermiteHoy ? 6 : -3;
    score += elemento.tipo == 'obra' ? 4 : 2;
    score += _estadoMentalBoost(estadoMental);
    score += (obj.estado == 'pendiente' ? 5 : 0);
    return score;
  }

  bool _categoriaPermiteHoy(List<Categoria> categorias, String? categoriaNombre) {
    if (categoriaNombre == null || categoriaNombre.isEmpty) return true;
    final categoria = categorias.firstWhere(
      (c) => c.nombre == categoriaNombre,
      orElse: () => Categoria(id: '', nombre: categoriaNombre),
    );
    final hoy = DateTime.now().weekday;
    final dias = categoria.diasList;
    switch (hoy) {
      case DateTime.monday:
        return dias.any((d) => d.toLowerCase() == 'lun');
      case DateTime.tuesday:
        return dias.any((d) => d.toLowerCase() == 'mar');
      case DateTime.wednesday:
        return dias.any((d) => d.toLowerCase() == 'mie');
      case DateTime.thursday:
        return dias.any((d) => d.toLowerCase() == 'jue');
      case DateTime.friday:
        return dias.any((d) => d.toLowerCase() == 'vie');
      case DateTime.saturday:
        return dias.any((d) => d.toLowerCase() == 'sab');
      case DateTime.sunday:
        return dias.any((d) => d.toLowerCase() == 'dom');
      default:
        return true;
    }
  }

  double _estadoMentalBoost(String estadoMental) {
    switch (estadoMental) {
      case 'bajo':
        return 8;
      case 'neutral':
        return 2;
      case 'alto':
        return -2;
      default:
        return 0;
    }
  }

  String _motivoObjetivo({
    required Preparacion prep,
    required Segmento? seg,
    required Objetivo obj,
  }) {
    final partes = <String>[];
    if (seg != null) {
      partes.add('objetivo de segmento');
    } else {
      partes.add('objetivo de preparación');
    }
    if (obj.prioridad >= 4) {
      partes.add('prioridad alta');
    }
    if (prep.fechaObjetivo != null) {
      final dias = prep.fechaObjetivo!.difference(DateTime.now()).inDays;
      if (dias <= 7) {
        partes.add('fecha límite próxima');
      }
    }
    if (obj.estadoMental != null) {
      partes.add('estado mental ${obj.estadoMental}');
    }
    if (obj.puntos <= 0) {
      partes.add('sin puntos aún');
    }
    return partes.join(' · ');
  }
}

class _CandidatoObjetivo {
  final Preparacion preparacion;
  final Segmento? segmento;
  final Objetivo objetivo;
  final double score;
  final String motivo;

  _CandidatoObjetivo({
    required this.preparacion,
    required this.segmento,
    required this.objetivo,
    required this.score,
    required this.motivo,
  });
}
