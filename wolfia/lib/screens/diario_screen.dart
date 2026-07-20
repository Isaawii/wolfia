import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../theme.dart';

class DiarioScreen extends StatefulWidget {
  const DiarioScreen({super.key});

  @override
  State<DiarioScreen> createState() => _DiarioScreenState();
}

class _DiarioScreenState extends State<DiarioScreen> {
  final _db = WolfiaDb.instance;
  List<Sesion> _historial = [];
  List<Nota> _notas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final historial = await _db.getHistorial();
    final notas = await _db.getDiario();
    setState(() {
      _historial = historial;
      _notas = notas;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final df = DateFormat('d MMM yyyy, HH:mm', 'es');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diario'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [Tab(text: 'Sesiones'), Tab(text: 'Notas')],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _cargar,
              child: _historial.isEmpty
                  ? _vacio('Todavía no completaste ninguna sesión.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _historial.length,
                      itemBuilder: (ctx, i) {
                        final s = _historial[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.check_circle,
                                color: AppColors.success),
                            title: Text(df.format(s.fecha)),
                            subtitle: Text(
                                '${s.duracionReal ?? s.duracionPlaneada} minutos'),
                          ),
                        );
                      },
                    ),
            ),
            RefreshIndicator(
              onRefresh: _cargar,
              child: _notas.isEmpty
                  ? _vacio('Todavía no escribiste ninguna nota.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _notas.length,
                      itemBuilder: (ctx, i) {
                        final n = _notas[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.contenido),
                                const SizedBox(height: AppSpacing.xs),
                                Text(df.format(n.fecha),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vacio(String texto) {
    return LayoutBuilder(
      builder: (ctx, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(texto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ),
      ),
    );
  }
}
