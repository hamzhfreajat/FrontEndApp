class LiveTicker {
  final int id;
  final String message;

  LiveTicker({
    required this.id,
    required this.message,
  });

  factory LiveTicker.fromJson(Map<String, dynamic> json) {
    return LiveTicker(
      id: json['id'],
      message: json['message'],
    );
  }
}
