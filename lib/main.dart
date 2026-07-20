import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/repertorio_screen.dart';
import 'screens/sesion_screen.dart';
import 'screens/diario_screen.dart';
import 'screens/dominio_screen.dart';

void main() {
  runApp(const WolfiaApp());
}

class WolfiaApp extends StatelessWidget {
  const WolfiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wolfia',
      debugShowCheckedModeBanner: false,
      theme: buildWolfiaTheme(),
      home: const RootNav(),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;

final _pages = [
      const DashboardScreen(),
      const RepertorioScreen(tipo: 'obra'),
      const RepertorioScreen(tipo: 'ejercicio'),
      const SesionScreen(),
      const DiarioScreen(),
      const DominioScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music_rounded), label: 'Repertorio'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded), label: 'Ejercicio'),
          BottomNavigationBarItem(icon: Icon(Icons.timer_rounded), label: 'Sesión'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: 'Diario'),
          BottomNavigationBarItem(icon: Icon(Icons.hub_rounded), label: 'Dominio'),
        ],
      ),
    );
  }
}
