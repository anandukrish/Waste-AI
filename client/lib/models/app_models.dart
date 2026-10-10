class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.mode,
    required this.createdAt,
  });

  final String role;
  final String content;
  final String mode;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'mode': mode,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String? ?? 'assistant',
        content: json['content'] as String? ?? '',
        mode: json['mode'] as String? ?? 'offline',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class Note {
  const Note({required this.id, required this.text, required this.createdAt});

  final String id;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class AppSettings {
  const AppSettings({
    this.host = 'http://127.0.0.1:8765',
    this.mode = 'offline',
    this.showSetup = true,
    this.autoSpeak = false,
    this.voiceLanguage = 'ml-IN',
    this.voiceRate = 0.5,
    this.voiceVolume = 1.0,
  });

  final String host;
  final String mode;
  final bool showSetup;
  final bool autoSpeak;
  final String voiceLanguage;
  final double voiceRate;
  final double voiceVolume;

  AppSettings copyWith({
    String? host,
    String? mode,
    bool? showSetup,
    bool? autoSpeak,
    String? voiceLanguage,
    double? voiceRate,
    double? voiceVolume,
  }) =>
      AppSettings(
        host: host ?? this.host,
        mode: mode ?? this.mode,
        showSetup: showSetup ?? this.showSetup,
        autoSpeak: autoSpeak ?? this.autoSpeak,
        voiceLanguage: voiceLanguage ?? this.voiceLanguage,
        voiceRate: voiceRate ?? this.voiceRate,
        voiceVolume: voiceVolume ?? this.voiceVolume,
      );
}
