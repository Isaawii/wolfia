import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../services/session_generator.dart';
import '../theme.dart';
import 'sesion_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = WolfiaDb.instance;
  Sesion? _sesionEnCurso;
  List<Preparacion> _activas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final sesion = await _db.getSesionEnCurso();
    final activas = await _db.getPreparacionesActivas();
    setState(() {
      _sesionEnCurso = sesion;
      _activas = activas;
      _cargando = false;
    });
  }

  Future<void> _generarSesion(int minutos) async {
    final gen = SessionGenerator();
    final sesion = await gen.generar(minutosDisponibles: minutos);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SesionActivaScreen(sesionId: sesion.id),
    ));
    _cargar();
  }

  void _preguntarDuracion() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Cuánto tiempo tenés hoy?',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [15, 30, 45, 60, 90].map((m) {
                return ActionChip(
                  label: Text('$m min'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _generarSesion(m);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('Wolfia')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _saludo(),
            const SizedBox(height: AppSpacing.md),
            if (_sesionEnCurso != null)
              _tarjetaContinuar()
            else
              _tarjetaGenerar(),
            const SizedBox(height: AppSpacing.lg),
            Text('Preparaciones activas',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (_activas.isEmpty)
              const _EmptyHint(
                texto: 'Todavía no tenés preparaciones activas.\n'
                    'Andá a la pestaña Repertorio para crear la primera.',
              )
            else
              ..._activas.map((p) => _tarjetaPreparacion(p)),
          ],
        ),
      ),
    );
  }

  Widget _saludo() {
    final hora = DateTime.now().hour;
    final saludo = hora < 12
        ? 'Buenos días'
        : (hora < 20 ? 'Buenas tardes' : 'Buenas noches');
    return Text(saludo, style: Theme.of(context).textTheme.headlineMedium);
  }

  Widget _tarjetaContinuar() {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        title: const Text('Tenés una sesión en curso'),
        subtitle: Text('${_sesionEnCurso!.duracionPlaneada} minutos planeados'),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.of(context)
                .push(MaterialPageRoute(
                  builder: (_) =>
                      SesionActivaScreen(sesionId: _sesionEnCurso!.id),
                ))
                .then((_) => _cargar());
          },
          child: const Text('Continuar'),
        ),
      ),
    );
  }

  Widget _tarjetaGenerar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesión de hoy',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Wolfia arma una propuesta de sesión según lo que hace '
              'más tiempo que no practicás y tus objetivos pendientes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _preguntarDuracion,
                child: const Text('Generar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPreparacion(Preparacion p) {
    return Card(
      child: ListTile(
        title: Text(p.nombre),
        subtitle: Text('Estado: ${p.estado}'),
        trailing: Text('${p.puntos} pts',
            style: const TextStyle(color: AppColors.primary)),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String texto;
  const _EmptyHint({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surface2),
      ),
      child:
          Text(texto, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}
