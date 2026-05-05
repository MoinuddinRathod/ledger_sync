import '../../../core/service/local_db_service/local_db_service.dart';

class DashboardRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<Map<String, dynamic>> getBalances(int accountId) async {
    return await _db.getDashboardBalances(accountId);
  }

  Future<Map<String, dynamic>> getIncomeExpense(
    int accountId, {
    String? monthYear,
  }) async {
    return await _db.getDashboardIncomeExpense(accountId, monthYear: monthYear);
  }
}
