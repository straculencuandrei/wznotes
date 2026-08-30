class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String title;
  final String releaseNotes;
  final String windowsUrl;
  final String androidUrl;
  final bool isMandatory;
  final String publishedAt;

  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    this.title = 'New Update Available',
    this.releaseNotes = '',
    this.windowsUrl = '',
    this.androidUrl = '',
    this.isMandatory = false,
    this.publishedAt = '',
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'build_number': buildNumber,
        'title': title,
        'release_notes': releaseNotes,
        'windows_url': windowsUrl,
        'android_url': androidUrl,
        'is_mandatory': isMandatory,
        'published_at': publishedAt,
      };

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: json['version'] as String? ?? '0.0.0',
      buildNumber: json['build_number'] as int? ?? 0,
      title: json['title'] as String? ?? 'New Update Available',
      releaseNotes: json['release_notes'] as String? ?? '',
      windowsUrl: json['windows_url'] as String? ?? '',
      androidUrl: json['android_url'] as String? ?? '',
      isMandatory: json['is_mandatory'] as bool? ?? false,
      publishedAt: json['published_at'] as String? ?? '',
    );
  }
}
