/// 読書セッション
class ReadingSession {
  final String id;
  final String userBookId;
  final String startedAt;
  final String? endedAt;
  final int startPage;
  final int? endPage;
  final int? durationMinutes;
  final String createdAt;

  const ReadingSession({
    required this.id,
    required this.userBookId,
    required this.startedAt,
    this.endedAt,
    required this.startPage,
    this.endPage,
    this.durationMinutes,
    required this.createdAt,
  });

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      id: json['id'] as String,
      userBookId: json['userBookId'] as String,
      startedAt: json['startedAt'] as String,
      endedAt: json['endedAt'] as String?,
      startPage: json['startPage'] as int,
      endPage: json['endPage'] as int?,
      durationMinutes: json['durationMinutes'] as int?,
      createdAt: json['createdAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userBookId': userBookId,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'startPage': startPage,
      'endPage': endPage,
      'durationMinutes': durationMinutes,
      'createdAt': createdAt,
    };
  }

  factory ReadingSession.fromSupabase(Map<String, dynamic> json) {
    return ReadingSession(
      id: json['id'] as String,
      userBookId: json['user_book_id'] as String,
      startedAt: json['started_at'] as String,
      endedAt: json['ended_at'] as String?,
      startPage: json['start_page'] as int,
      endPage: json['end_page'] as int?,
      durationMinutes: json['duration_minutes'] as int?,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_book_id': userBookId,
      'started_at': startedAt,
      'ended_at': endedAt,
      'start_page': startPage,
      'end_page': endPage,
      'duration_minutes': durationMinutes,
      'created_at': createdAt,
    };
  }
}
