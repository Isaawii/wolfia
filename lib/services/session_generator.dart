import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../models/models.dart';

/// Versión simplificada del "Motor Generador de Sesiones" del documento.
/// Nada de Isolates, nada de aprendizaje automático: una fórmula de
/// prioridad clara y explicable, suficiente para uso personal.
class SessionGenerator {
  final _uuid = const Uuid();
  final _db = WolfiaDb.instance;

  /// Genera una sesión nueva repartiendo [minutosDisponibles] entre las
  /// preparaciones activas, priorizando según:
  /// - días sin practicar
  /// - prioridad del segmento
  /// - objetivos pendientes
  Future<Sesion> generar({required int minutosDisponibles}) async {
    final preparaciones = await _db.getPreparacionesActivas();
    final segmentos = await _db.getTodosSegmentosActivos();

    if (preparaciones.isEmpty) {
      // Sesión libre: no hay nada configurado todavía.
      final sesion = Sesion(
        id: _uuid.v4(),
        fecha: DateTime.now(),
        duracionPlaneada: minutosDisponibles,
        estado: 'generada',
      );
      await _db.insertSesion(sesion);
      return sesion;
    }

    // 1. Puntaje por preparación (basado en sus segmentos + objetivos)
    final candidatos = <_Candidato>[];
    for (final prep in preparaciones) {
      final segsDePrep = segmentos.where((s) => s.preparacionId == prep.id).toList();
      final objetivos = await _db.getObjetivos(prep.id);
      final objetivosPendientes =
          objetivos.where((o) => o.estado != 'cumplido' && o.estado != 'descartado').length;

      if (segsDePrep.isEmpty) {
        // Preparación sin segmentos: se trata como un único bloque.
        final diasSinPracticar = prep.ultimaPractica == null
            ? 999
            : DateTime.now().difference(prep.ultimaPractica!).inDays;
        final score = _scorePreparacion(diasSinPracticar, objetivosPendientes);
        candidatos.add(_Candidato(
          preparacion: prep,
          segmento: null,
          score: score,
          motivo: _motivoPreparacion(diasSinPracticar, objetivosPendientes),
        ));
      } else {
        for (final seg in segsDePrep) {
          final dias = seg.diasSinPracticar();
          final score = _scoreSegmento(seg, dias, objetivosPendientes);
          candidatos.add(_Candidato(
            preparacion: prep,
            segmento: seg,
            score: score,
            motivo: _motivoSegmento(seg, dias, objetivosPendientes),
          ));
        }
      }
    }

    candidatos.sort((a, b) => b.score.compareTo(a.score));

    // 2. Repartir el tiempo disponible entre los mejores candidatos,
    //    con un mínimo de 8 minutos y máximo de 25 por tarea, alternando.
    const minPorTarea = 8;
    const maxPorTarea = 25;
    int restante = minutosDisponibles;
    final tareas = <Tarea>[];

    final sesion = Sesion(
      id: _uuid.v4(),
      fecha: DateTime.now(),
      duracionPlaneada: minutosDisponibles,
      estado: 'generada',
    );
    await _db.insertSesion(sesion);

    for (final c in candidatos) {
      if (restante < minPorTarea) break;
      final minutos = restante >= maxPorTarea ? maxPorTarea : restante;
      if (minutos < minPorTarea) break;

      final tarea = Tarea(
        id: _uuid.v4(),
        sesionId: sesion.id,
        preparacionId: c.preparacion.id,
        segmentoId: c.segmento?.id,
        tituloPreparacion: c.preparacion.nombre,
        tituloSegmento: c.segmento?.nombre,
        minutosPlaneados: minutos,
        motivo: c.motivo,
      );
      await _db.insertTarea(tarea);
      tareas.add(tarea);
      restante -= minutos;
    }

    return sesion;
  }

  /// Planifica una sesión y devuelve la estructura (sesión + tareas) sin
  /// persistirla en la base de datos — útil para previsualizar el plan.
  Future<Map<String, dynamic>> planificar({required int minutosDisponibles}) async {
    final preparaciones = await _db.getPreparacionesActivas();
    final segmentos = await _db.getTodosSegmentosActivos();

    final candidatos = <_Candidato>[];
    if (preparaciones.isNotEmpty) {
      for (final prep in preparaciones) {
        final segsDePrep = segmentos.where((s) => s.preparacionId == prep.id).toList();
        final objetivos = await _db.getObjetivos(prep.id);
        final objetivosPendientes = objetivos.where((o) => o.estado != 'cumplido' && o.estado != 'descartado').length;

        if (segsDePrep.isEmpty) {
          final diasSinPracticar = prep.ultimaPractica == null
              ? 999
              : DateTime.now().difference(prep.ultimaPractica!).inDays;
          final score = _scorePreparacion(diasSinPracticar, objetivosPendientes);
          candidatos.add(_Candidato(
            preparacion: prep,
            segmento: null,
            score: score,
            motivo: _motivoPreparacion(diasSinPracticar, objetivosPendientes),
          ));
        } else {
          for (final seg in segsDePrep) {
            final dias = seg.diasSinPracticar();
            final score = _scoreSegmento(seg, dias, objetivosPendientes);
            candidatos.add(_Candidato(
              preparacion: prep,
              segmento: seg,
              score: score,
              motivo: _motivoSegmento(seg, dias, objetivosPendientes),
            ));
          }
        }
      }
    }

    candidatos.sort((a, b) => b.score.compareTo(a.score));

    const minPorTarea = 8;
    const maxPorTarea = 25;
    int restante = minutosDisponibles;
    final tareas = <Tarea>[];

    final sesion = Sesion(
      id: _uuid.v4(),
      fecha: DateTime.now(),
      duracionPlaneada: minutosDisponibles,
      estado: 'generada',
    );

    for (final c in candidatos) {
      if (restante < minPorTarea) break;
      final minutos = restante >= maxPorTarea ? maxPorTarea : restante;
      if (minutos < minPorTarea) break;

      final tarea = Tarea(
        id: _uuid.v4(),
        sesionId: sesion.id,
        preparacionId: c.preparacion.id,
        segmentoId: c.segmento?.id,
        tituloPreparacion: c.preparacion.nombre,
        tituloSegmento: c.segmento?.nombre,
        minutosPlaneados: minutos,
        motivo: c.motivo,
      );
      tareas.add(tarea);
      restante -= minutos;
    }

    return {'sesion': sesion, 'tareas': tareas};
  }

  double _scoreSegmento(Segmento seg, int diasSinPracticar, int objetivosPendientes) {
    double score = 10;
    score += seg.prioridad * 8; // 1-5 -> 8-40
    score += diasSinPracticar.clamp(0, 30) * 1.5;
    score += objetivosPendientes * 6;
    if (seg.estado == 'activo') score += 10;
    return score;
  }

  double _scorePreparacion(int diasSinPracticar, int objetivosPendientes) {
    double score = 15;
    score += diasSinPracticar.clamp(0, 30) * 1.5;
    score += objetivosPendientes * 6;
    return score;
  }

  String _motivoSegmento(Segmento seg, int dias, int objetivosPendientes) {
    final partes = <String>[];
    if (dias >= 999) {
      partes.add('nunca se practicó');
    } else if (dias > 0) {
      partes.add('hace $dias día${dias == 1 ? '' : 's'} que no se practica');
    }
    if (seg.prioridad >= 4) partes.add('prioridad alta');
    if (objetivosPendientes > 0) {
      partes.add('$objetivosPendientes objetivo${objetivosPendientes == 1 ? '' : 's'} pendiente${objetivosPendientes == 1 ? '' : 's'}');
    }
    return partes.isEmpty ? 'toca en la rotación' : partes.join(' · ');
  }

  String _motivoPreparacion(int dias, int objetivosPendientes) {
    final partes = <String>[];
    if (dias >= 999) {
      partes.add('todavía no tiene sesiones');
    } else {
      partes.add('hace $dias día${dias == 1 ? '' : 's'} que no se practica');
    }
    if (objetivosPendientes > 0) {
      partes.add('$objetivosPendientes objetivo${objetivosPendientes == 1 ? '' : 's'} pendiente${objetivosPendientes == 1 ? '' : 's'}');
    }
    return partes.join(' · ');
  }
}

class _Candidato {
  final Preparacion preparacion;
  final Segmento? segmento;
  final double score;
  final String motivo;

  _Candidato({
    required this.preparacion,
    required this.segmento,
    required this.score,
    required this.motivo,
  });
}
