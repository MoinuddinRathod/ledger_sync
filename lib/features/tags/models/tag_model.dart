import 'dart:convert';
import '../../../core/utils/app_constants.dart';

class TagModel {
  int? tagId;
  final String tagName;
  final List<Map<String, dynamic>> tagKeywords;
  final int tagPriority;
  final String? tagBankAccountId;
  final int? tagUserId;
  final String tagCreatedAt;
  final String? tagUpdatedAt;
  final String? tagDeletedAt;

  // Transaction Totals
  final double totalDr;
  final double totalCr;

  TagModel({
    this.tagId,
    required this.tagName,
    required this.tagKeywords,
    required this.tagPriority,
    this.tagBankAccountId,
    this.tagUserId,
    required this.tagCreatedAt,
    this.tagUpdatedAt,
    this.tagDeletedAt,
    this.totalDr = 0.0,
    this.totalCr = 0.0,
  });

  // ------------------ FROM MAP (SQLite) ------------------ //
  factory TagModel.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> keywordsList = [];
    if (map[TAG_KEYWORDS] != null) {
      if (map[TAG_KEYWORDS] is String) {
        final decoded = jsonDecode(map[TAG_KEYWORDS]);
        if (decoded is List) {
          keywordsList = List<Map<String, dynamic>>.from(decoded);
        }
      }
    }

    return TagModel(
      tagId: map[TAG_ID] as int,
      tagName: map[TAG_NAME] as String,
      tagKeywords: keywordsList,
      tagPriority: map[TAG_PRIORITY] as int,
      tagBankAccountId: map[TAG_BANK_ACCOUNT_ID] as String?,
      tagUserId: map[TAG_USER_ID] as int?,
      tagCreatedAt: map[TAG_CREATED_AT] as String,
      tagUpdatedAt: map[TAG_UPDATED_AT] as String?,
      tagDeletedAt: map[TAG_DELETED_AT] as String?,
      totalDr: (map['totalDr'] as num?)?.toDouble() ?? 0.0,
      totalCr: (map['totalCr'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ------------------ TO MAP (SQLite) ------------------ //
  Map<String, dynamic> toMap() {
    return {
      TAG_NAME: tagName,
      TAG_KEYWORDS: jsonEncode(tagKeywords),
      TAG_PRIORITY: tagPriority,
      TAG_BANK_ACCOUNT_ID: tagBankAccountId,
      TAG_USER_ID: tagUserId,
      TAG_CREATED_AT: tagCreatedAt,
      TAG_UPDATED_AT: tagUpdatedAt,
      TAG_DELETED_AT: tagDeletedAt,
      // totalDr and totalCr are typically not saved directly to the database
      // as they are aggregated, but you can include them in map representations if needed
    };
  }

  // ------------------ FROM JSON (API / serialisation) ------------------ //
  factory TagModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> keywordsList = [];
    if (json[TAG_KEYWORDS] != null) {
      if (json[TAG_KEYWORDS] is List) {
        keywordsList = List<Map<String, dynamic>>.from(json[TAG_KEYWORDS]);
      } else if (json[TAG_KEYWORDS] is String) {
        final decoded = jsonDecode(json[TAG_KEYWORDS]);
        if (decoded is List) {
            keywordsList = List<Map<String, dynamic>>.from(decoded);
        }
      }
    }

    return TagModel(
      tagId: json[TAG_ID] as int,
      tagName: json[TAG_NAME] as String,
      tagKeywords: keywordsList,
      tagPriority: json[TAG_PRIORITY] as int,
      tagBankAccountId: json[TAG_BANK_ACCOUNT_ID] as String?,
      tagUserId: json[TAG_USER_ID] as int?,
      tagCreatedAt: json[TAG_CREATED_AT] as String,
      tagUpdatedAt: json[TAG_UPDATED_AT] as String?,
      tagDeletedAt: json[TAG_DELETED_AT] as String?,
      totalDr: (json['totalDr'] as num?)?.toDouble() ?? 0.0,
      totalCr: (json['totalCr'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ------------------ TO JSON (API / serialisation) ------------------ //
  Map<String, dynamic> toJson() {
    return {
      TAG_ID: tagId,
      TAG_NAME: tagName,
      TAG_KEYWORDS: tagKeywords,
      TAG_PRIORITY: tagPriority,
      TAG_BANK_ACCOUNT_ID: tagBankAccountId,
      TAG_USER_ID: tagUserId,
      TAG_CREATED_AT: tagCreatedAt,
      TAG_UPDATED_AT: tagUpdatedAt,
      TAG_DELETED_AT: tagDeletedAt,
      'totalDr': totalDr,
      'totalCr': totalCr,
    };
  }

  // ------------------ COPY WITH ------------------ //
  TagModel copyWith({
    int? tagId,
    String? tagName,
    List<Map<String, dynamic>>? tagKeywords,
    int? tagPriority,
    String? tagBankAccountId,
    int? tagUserId,
    String? tagCreatedAt,
    String? tagUpdatedAt,
    String? tagDeletedAt,
    double? totalDr,
    double? totalCr,
  }) {
    return TagModel(
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
      tagKeywords: tagKeywords ?? this.tagKeywords,
      tagPriority: tagPriority ?? this.tagPriority,
      tagBankAccountId: tagBankAccountId ?? this.tagBankAccountId,
      tagUserId: tagUserId ?? this.tagUserId,
      tagCreatedAt: tagCreatedAt ?? this.tagCreatedAt,
      tagUpdatedAt: tagUpdatedAt ?? this.tagUpdatedAt,
      tagDeletedAt: tagDeletedAt ?? this.tagDeletedAt,
      totalDr: totalDr ?? this.totalDr,
      totalCr: totalCr ?? this.totalCr,
    );
  }
}
