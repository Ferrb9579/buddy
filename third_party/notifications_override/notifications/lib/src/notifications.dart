import 'dart:async';
import 'package:flutter/services.dart';
import 'notification_event.dart';

class Notifications {
  static const EventChannel _eventChannel = EventChannel('notifications.eventChannel');

  Stream<NotificationEvent>? _notificationStream;

  /// Stream of notification events
  Stream<NotificationEvent>? get notificationStream {
    _notificationStream ??= _eventChannel.receiveBroadcastStream().map((event) => NotificationEvent.fromMap(event as Map<dynamic, dynamic>));
    return _notificationStream;
  }
}
