class RunFeelTag {
  final String id;
  final String labelJa;
  final String labelEn;

  const RunFeelTag({
    required this.id,
    required this.labelJa,
    required this.labelEn,
  });
}

const runFeelTags = [
  RunFeelTag(id: 'stable', labelJa: '安定', labelEn: 'Stable'),
  RunFeelTag(id: 'push', labelJa: '曲がらない', labelEn: 'Push'),
  RunFeelTag(id: 'spin', labelJa: '巻く', labelEn: 'Spin'),
  RunFeelTag(id: 'loose_rear', labelJa: 'リアが軽い', labelEn: 'Loose rear'),
  RunFeelTag(id: 'no_power', labelJa: '握れない', labelEn: 'Hard to power'),
  RunFeelTag(id: 'drive', labelJa: '前に出る', labelEn: 'Drives forward'),
  RunFeelTag(id: 'bounce', labelJa: '跳ねる', labelEn: 'Bounces'),
  RunFeelTag(id: 'turns_well', labelJa: 'よく曲がる', labelEn: 'Turns well'),
];

String runFeelTagLabel(String id, bool isEnglish) {
  for (final tag in runFeelTags) {
    if (tag.id == id) {
      return isEnglish ? tag.labelEn : tag.labelJa;
    }
  }
  return id;
}
