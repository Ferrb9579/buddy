import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:buddy/routes/app_pages.dart';
import 'package:buddy/services/reminder_service.dart';
import 'package:buddy/services/notification_ingest_service.dart';
import 'package:buddy/services/toast_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  // Load local environment variables from .env, if present (non-fatal on missing file)
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (_) {
    // ignore load failures; rely on --dart-define values instead
  }
  // Initialize reminders
  final reminders = ReminderService();
  await reminders.initialize();
  // Start notification ingestion on Android if user enabled
  if (!kIsWeb && Platform.isAndroid) {
    final ingest = NotificationIngestService();
    final enabled = await ingest.getEnabled();
    if (enabled) {
      await ingest.start();
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      scaffoldMessengerKey: ToastService().messengerKey,
    );
  }
}
