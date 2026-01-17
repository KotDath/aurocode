import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'features/ide_layout/presentation/ide_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Aurocode IDE',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    const ProviderScope(
      child: AurocodeIDE(),
    ),
  );
}

class AurocodeIDE extends StatelessWidget {
  const AurocodeIDE({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aurocode IDE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const IdeLayout(),
    );
  }
}

