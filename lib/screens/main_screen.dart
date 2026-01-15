import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'second_screen.dart';
import 'third_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Используем ключи для пересоздания экранов при переключении
  // Это позволяет таймерам сбрасываться при каждом показе экрана
  final List<GlobalKey> _screenKeys = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];

  List<Widget> get _screens => [
    HomeScreen(key: _screenKeys[0]),
    SecondScreen(key: _screenKeys[1]),
    ThirdScreen(key: _screenKeys[2]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            // Пересоздаем экран при переключении для сброса таймера
            _screenKeys[index] = GlobalKey();
            setState(() {
              _currentIndex = index;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Вторая',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Третья',
          ),
        ],
      ),
    );
  }
}
