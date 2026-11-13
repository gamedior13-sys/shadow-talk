import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/lesson_repository.dart';
import 'screens/home_screen.dart';
import 'screens/my_content_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';
import 'services/asr_service.dart';
import 'services/content_sync_service.dart';
import 'services/player_service.dart';
import 'services/recorder_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

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
        Provider(create: (_) => AsrService()),
        Provider(create: (c) => ContentSyncService(c.read<LessonRepository>())),
      ],
      child: MaterialApp(
        title: 'Shadow Talk',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.light(
            primary: kBlue,
            secondary: kBlue,
            surface: kCard,
            error: kRed,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: kCard,
            surfaceTintColor: kCard,
            foregroundColor: kText,
            elevation: 0.5,
          ),
          cardTheme: CardThemeData(
            color: kCard,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: kLine),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
            ),
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
