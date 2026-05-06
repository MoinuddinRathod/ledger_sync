import '../../../core/service/local_db_service/local_db_service.dart';
import '../../../core/service/local_storage_service.dart';
import '../models/tag_model.dart';

class TagRepository {
  // ----- for making db method call ----- //
  var db = DatabaseHelper.instance;

  // ----- business logic methods ----- //

  // add tag -------- //
  Future<int> addTag(TagModel model) async {
    return await db.insertTag(model);
  }

  // get all tags (global — no user/bank filter) -------- //
  Future<List<TagModel>> getAllTags() async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return [];
    return await db.getAllTags(accountId);
  }

  // get tags by user id (account-level) -------- //
  Future<List<TagModel>> getTagsByUserId(int userId) async {
    return await db.getTagsByUserId(userId);
  }

  // get tags by bank account id -------- //
  Future<List<TagModel>> getTagsByBankAccountId(String bankAccountId) async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return [];
    return await db.getTagsByBankAccountId(bankAccountId, accountId);
  }

  // update tag -------- //
  Future<int> updateTag(TagModel model) async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return 0;
    return await db.updateTag(model, accountId);
  }

  // soft delete tag -------- //
  Future<int> deleteTag(int tagId) async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return 0;
    return await db.deleteTag(tagId, accountId);
  }
}
