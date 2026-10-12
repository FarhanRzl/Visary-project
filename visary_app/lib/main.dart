import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/local/database.dart';
import 'data/local/project_repository.dart';
import 'screens/asset_library_screen.dart';
import 'screens/clip_editor_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/hook_finder_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/upload_screen.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';
import 'package:fvp/fvp.dart' as fvp;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Global Flutter error catching
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  // Register fvp as the video player backend for linux, windows, macos
  fvp.registerWith(options: {
    'platforms': ['linux', 'windows', 'macos']
  });
  
  // Inisialisasi database persistensi & restore sesi
  final db = await VisaryDatabase.open();
  final repo = ProjectRepository(db);
  final appState = AppState(repo: repo);
  await appState.restoreSession();
  await appState.loadAiSettings();
  await appState.loadProjects();
  
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const VisaryApp(),
    ),
  );
}

class VisaryApp extends StatelessWidget {
  const VisaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VISARY',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      initialRoute: context.read<AppState>().user != null ? '/dashboard' : '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/upload': (_) => const UploadScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/assets': (_) => const AssetLibraryScreen(),
      },
      onGenerateRoute: (settings) {
        final id = settings.arguments as String?;
        switch (settings.name) {
          case '/editor':
            return MaterialPageRoute(
              builder: (_) => ClipEditorScreen(projectId: id ?? ''),
            );
          case '/hooks':
            return MaterialPageRoute(
              builder: (_) => HookFinderScreen(projectId: id ?? ''),
            );
        }
        return null;
      },
    );
  }
}
