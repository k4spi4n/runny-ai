import 'dart:convert';

/// Một chỉnh sửa do HLV đề xuất. Thao tác chỉ được ghi vào Supabase sau khi
/// người dùng bấm xác nhận trên thẻ tương tác trong cuộc trò chuyện.
class CoachInteractiveAction {
  final String kind;
  final String targetId;
  final String title;
  final Map<String, dynamic> before;
  final Map<String, dynamic> changes;
  final String status;

  const CoachInteractiveAction({
    required this.kind,
    required this.targetId,
    required this.title,
    required this.before,
    required this.changes,
    this.status = 'pending',
  });

  bool get isPending => status == 'pending';

  CoachInteractiveAction copyWith({String? status}) => CoachInteractiveAction(
    kind: kind,
    targetId: targetId,
    title: title,
    before: before,
    changes: changes,
    status: status ?? this.status,
  );

  factory CoachInteractiveAction.fromJson(Map<String, dynamic> json) =>
      CoachInteractiveAction(
        kind: json['kind'] as String,
        targetId: json['target_id'] as String,
        title: json['title'] as String? ?? '',
        before: Map<String, dynamic>.from(json['before'] as Map? ?? const {}),
        changes: Map<String, dynamic>.from(json['changes'] as Map? ?? const {}),
        status: json['status'] as String? ?? 'pending',
      );

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'target_id': targetId,
    'title': title,
    'before': before,
    'changes': changes,
    'status': status,
  };
}

class CoachToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final Map<String, dynamic> raw;

  const CoachToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    required this.raw,
  });

  factory CoachToolCall.fromJson(Map<String, dynamic> json) {
    final function = Map<String, dynamic>.from(
      json['function'] as Map? ?? const {},
    );
    final rawArguments = function['arguments'];
    Map<String, dynamic> arguments = const {};
    if (rawArguments is String && rawArguments.trim().isNotEmpty) {
      final decoded = jsonDecode(rawArguments);
      if (decoded is Map) arguments = Map<String, dynamic>.from(decoded);
    } else if (rawArguments is Map) {
      arguments = Map<String, dynamic>.from(rawArguments);
    }
    return CoachToolCall(
      id: json['id'] as String? ?? '',
      name: function['name'] as String? ?? '',
      arguments: arguments,
      raw: json,
    );
  }
}

class CoachToolExecution {
  final Map<String, dynamic> output;
  final CoachInteractiveAction? action;

  const CoachToolExecution({required this.output, this.action});
}

class CoachTurnResult {
  final String content;
  final List<CoachInteractiveAction> actions;

  const CoachTurnResult({required this.content, this.actions = const []});
}
