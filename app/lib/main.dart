import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/lesson_repository.dart';
import 'screens/home_screen.dart';
import 'screens/my_content_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';
import 'services/player_service.dart';
import 'services/recorder_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlayerService.initBackground();
  final appState = AppState();
  await appState.load();
  runApp(ShadowTalkApp(appState: appState));
}

class ShadowTalkApp extends StatelessWidget {
  final AppState appState;
  const ShadowTalkApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        Provider(create: (_) => LessonRepository()),
        Provider(create: (_) => PlayerService()),
        Provider(create: (_) => RecorderService()),
      ],
      child: MaterialApp(
        title: 'Shadow Talk',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFB703),
            secondary: Color(0xFF4493F8),
            surface: Color(0xFF161B22),
          ),
        ),
        home: const RootScaffold(),
      ),
    );
  }
}

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _tab = 0;
  static const _screens = [
    HomeScreen(),
    MyContentScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.library_books_outlined),
              selectedIcon: Icon(Icons.library_books),
              label: 'Bài học'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Của tôi'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Tiến độ'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Cài đặt'),
        ],
      ),
    );
  }
}
