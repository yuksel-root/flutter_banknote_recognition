import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bloc/scanner_bloc.dart';
import 'repository/banknote_repository.dart';
import 'services/camera_service.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final ttsService = TtsService();
  await ttsService.initialize();
  final cameraService = CameraService();
  final banknoteRepository = BanknoteRepository();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SharedPreferences>.value(value: preferences),
        RepositoryProvider<TtsService>.value(value: ttsService),
        RepositoryProvider<CameraService>.value(value: cameraService),
        RepositoryProvider<BanknoteRepository>.value(value: banknoteRepository),
      ],
      child: BlocProvider(
        create: (_) => ScannerBloc(repository: banknoteRepository),
        child: const BanknoteApp(),
      ),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(cameraService.initialize());
  });
}
