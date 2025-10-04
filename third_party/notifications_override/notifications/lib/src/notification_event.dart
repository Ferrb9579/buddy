class NotificationEvent {
  final String? packageName;
  final String? title;
  final String? message;
  final DateTime? timeStamp;

  NotificationEvent({
    this.packageName,
    this.title,
    this.message,
    this.timeStamp,
  });

  factory NotificationEvent.fromMap(Map<dynamic, dynamic> map) {
    return NotificationEvent(
      packageName: map['packageName'] as String?,
      title: map['title'] as String?,
      message: map['message'] as String?,
      timeStamp: map['timeStamp'] != null ? DateTime.fromMillisecondsSinceEpoch(map['timeStamp'] as int) : null,
    );
  }

  @override
  String toString() {
    return 'NotificationEvent{packageName: $packageName, title: $title, message: $message, timeStamp: $timeStamp}';
  }
}
