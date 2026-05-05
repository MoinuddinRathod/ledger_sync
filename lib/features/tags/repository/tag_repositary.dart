import '../../../core/service/local_db_service/local_db_service.dart';
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
    return await db.getAllTags();
  }

  // get tags by user id (account-level) -------- //
  Future<List<TagModel>> getTagsByUserId(int userId) async {
    return await db.getTagsByUserId(userId);
  }

  // get tags by bank account id -------- //
  Future<List<TagModel>> getTagsByBankAccountId(String bankAccountId) async {
    return await db.getTagsByBankAccountId(bankAccountId);
  }

  // update tag -------- //
  Future<int> updateTag(TagModel model) async {
    return await db.updateTag(model);
  }

  // soft delete tag -------- //
  Future<int> deleteTag(int tagId) async {
    return await db.deleteTag(tagId);
  }
}
