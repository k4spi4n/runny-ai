class CoachPersona {
  final String id;
  final String labelKey;
  final String descriptionKey;
  final String promptDescription;

  const CoachPersona({
    required this.id,
    required this.labelKey,
    required this.descriptionKey,
    required this.promptDescription,
  });

  static const calm = CoachPersona(
    id: 'calm',
    labelKey: 'coach_persona_calm',
    descriptionKey: 'coach_persona_calm_desc',
    promptDescription:
        'Điềm tĩnh, nhẹ nhàng, giải thích rõ ràng và phù hợp người mới.',
  );

  static const disciplined = CoachPersona(
    id: 'disciplined',
    labelKey: 'coach_persona_disciplined',
    descriptionKey: 'coach_persona_disciplined_desc',
    promptDescription:
        'Kỷ luật, thẳng vào vấn đề, ngắn gọn và tập trung vào mục tiêu.',
  );

  static const energetic = CoachPersona(
    id: 'energetic',
    labelKey: 'coach_persona_energetic',
    descriptionKey: 'coach_persona_energetic_desc',
    promptDescription:
        'Nhiều năng lượng, tích cực, động viên nhưng không phóng đại.',
  );

  static const scientific = CoachPersona(
    id: 'scientific',
    labelKey: 'coach_persona_scientific',
    descriptionKey: 'coach_persona_scientific_desc',
    promptDescription:
        'Thiên về dữ liệu, giải thích bằng pace, nhịp tim, tải tập và phục hồi.',
  );

  static const concise = CoachPersona(
    id: 'concise',
    labelKey: 'coach_persona_concise',
    descriptionKey: 'coach_persona_concise_desc',
    promptDescription:
        'Tối giản, trả lời ngắn, ưu tiên checklist và bước hành động rõ.',
  );

  static const values = [calm, disciplined, energetic, scientific, concise];

  static CoachPersona byId(String? id) {
    return values.firstWhere((persona) => persona.id == id, orElse: () => calm);
  }
}
