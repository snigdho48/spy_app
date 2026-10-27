class KeywordModel {
  const KeywordModel({required this.id, required this.word});

  final String id;
  final String word;

  String get chipLabel => word.startsWith('#') ? word : '#$word';

  factory KeywordModel.fromJson(Map<String, dynamic> json) {
    return KeywordModel(
      id: json['id'].toString(),
      word: (json['word'] as String? ?? '').trim(),
    );
  }
}
