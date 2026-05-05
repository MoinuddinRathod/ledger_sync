class TransactionModel {
  final String? id;
  final String title;
  final double amount;
  final String type; // 'income' | 'expense' | 'transfer'
  final DateTime date;
  final String category;
  final String? accountName;

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
    this.accountName,
  });

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? type,
    DateTime? date,
    String? category,
    String? accountName,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      category: category ?? this.category,
      accountName: accountName ?? this.accountName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'type': type,
    'date': date.toIso8601String(),
    'category': category,
    'accountName': accountName,
  };

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      TransactionModel(
        id: json['id'] as String?,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        type: json['type'] as String,
        date: DateTime.parse(json['date'] as String),
        category: json['category'] as String,
        accountName: json['accountName'] as String?,
      );
}

// ─────────────────────────────────────────────
// Supporting models (used in create/edit form)
// ─────────────────────────────────────────────

class AccountModel {
  final String id;
  final String name;

  AccountModel({required this.id, required this.name});
}

class CategoryModel {
  final String id;
  final String name;
  final String type; // 'income' | 'expense' | 'transfer'

  CategoryModel({required this.id, required this.name, required this.type});
}
