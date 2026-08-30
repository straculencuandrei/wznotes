class SyncNoteHeader {
  final String id;
  final int modifiedAt;
  final bool isDeleted;
  final String title;

  const SyncNoteHeader({
    required this.id,
    required this.modifiedAt,
    this.isDeleted = false,
    this.title = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'modifiedAt': modifiedAt,
        'isDeleted': isDeleted,
        'title': title,
      };

  factory SyncNoteHeader.fromJson(Map<String, dynamic> json) => SyncNoteHeader(
        id: json['id'] as String? ?? '',
        modifiedAt: json['modifiedAt'] as int? ?? 0,
        isDeleted: json['isDeleted'] as bool? ?? false,
        title: json['title'] as String? ?? '',
      );
}

class SyncManifest {
  final String deviceId;
  final String deviceName;
  final int timestamp;
  final List<SyncNoteHeader> notes;

  const SyncManifest({
    required this.deviceId,
    required this.deviceName,
    required this.timestamp,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'timestamp': timestamp,
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  factory SyncManifest.fromJson(Map<String, dynamic> json) => SyncManifest(
        deviceId: json['deviceId'] as String? ?? '',
        deviceName: json['deviceName'] as String? ?? 'Device',
        timestamp: json['timestamp'] as int? ?? 0,
        notes: (json['notes'] as List<dynamic>?)
                ?.map((e) => SyncNoteHeader.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class SyncResult {
  final bool success;
  final int notesUploaded;
  final int notesDownloaded;
  final int notesDeleted;
  final int conflictsResolved;
  final String? errorMessage;

  const SyncResult({
    required this.success,
    this.notesUploaded = 0,
    this.notesDownloaded = 0,
    this.notesDeleted = 0,
    this.conflictsResolved = 0,
    this.errorMessage,
  });

  factory SyncResult.failure(String message) => SyncResult(
        success: false,
        errorMessage: message,
      );
}
