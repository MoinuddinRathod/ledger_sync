import 'parse_result.dart';

/// Abstract base class for all bank statement parsers.
/// Each bank-specific parser should extend this class
/// and implement the [parse] method.
abstract class BankStatementParser {
  String get bankName;

  /// Parses the file at [filePath] and returns a [ParseResult]
  /// with detected [accountName] and [accountNumber].
  Future<ParseResult> parse(String filePath);

  /// Peeks at file headers to check if this parser can handle the file.
  /// Returns true if the file looks like it belongs to this bank.
  Future<bool> canParse(String filePath);

  /// Returns the file extension (lowercased) from a path.
  static String getExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }
}
