import 'package:flutter_test/flutter_test.dart';
import 'package:wolfia/services/session_generator.dart';

void main() {
  group('SessionGenerator', () {
    test('respeta el máximo del objetivo cuando hay tiempo suficiente', () {
      final generator = SessionGenerator();

      final minutos = generator.asignarDuracionObjetivo(
        minutosDisponibles: 30,
        tiempoMinimo: 10,
        tiempoMaximo: 20,
      );

      expect(minutos, 20);
    });

    test('no baja del mínimo cuando quedan pocos minutos', () {
      final generator = SessionGenerator();

      final minutos = generator.asignarDuracionObjetivo(
        minutosDisponibles: 8,
        tiempoMinimo: 10,
        tiempoMaximo: 25,
      );

      expect(minutos, 8);
    });
  });
}
