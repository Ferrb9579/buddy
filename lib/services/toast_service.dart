import 'package:flutter/material.dart';

class ToastService {
  static final ToastService _instance = ToastService._();
  ToastService._();
  factory ToastService() => _instance;

  final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  void show(String message, {Duration duration = const Duration(seconds: 2)}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), duration: duration, behavior: SnackBarBehavior.floating));
  }
}
