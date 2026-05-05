class KeywordMappingModel {
  final int? id;
  final String keyword; // UNIQUE
  final int masterAccountId; // FK to master_accounts
  final double confidence; // 0.0 to 1.0
  final int usageCount;
  final String createdAt;

  KeywordMappingModel({
    this.id,
    required this.keyword,
    required this.masterAccountId,
    this.confidence = 1.0,
    this.usageCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {};
  }

  factory KeywordMappingModel.fromMap(Map<String, dynamic> map) {
    return KeywordMappingModel(keyword: '', masterAccountId: 0, createdAt: '');
  }

  KeywordMappingModel copyWith({
    int? id,
    String? keyword,
    int? masterAccountId,
    double? confidence,
    int? usageCount,
    String? createdAt,
  }) {
    return KeywordMappingModel(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      masterAccountId: masterAccountId ?? this.masterAccountId,
      confidence: confidence ?? this.confidence,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Increment usage count
  KeywordMappingModel incrementUsage() {
    return copyWith(usageCount: usageCount + 1);
  }

  /// Update confidence using exponential moving average
  KeywordMappingModel updateConfidence(bool wasCorrect) {
    final newConfidence = wasCorrect
        ? confidence +
              (1 - confidence) *
                  0.1 // Increase confidence
        : confidence * 0.9; // Decrease confidence
    return copyWith(confidence: newConfidence.clamp(0.0, 1.0));
  }

  @override
  String toString() {
    return 'KeywordMappingModel(id: $id, keyword: $keyword, masterAccountId: $masterAccountId, confidence: $confidence, usageCount: $usageCount)';
  }
}
