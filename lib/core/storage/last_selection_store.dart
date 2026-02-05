import 'package:shared_preferences/shared_preferences.dart';

class LastSelectionStore {
  static const _kLastCategoryId = 'last_category_id';
  static const _kLastSubcategoryId = 'last_subcategory_id';

  Future<(String?, String?)> read() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getString(_kLastCategoryId), sp.getString(_kLastSubcategoryId));
  }

  Future<void> write({required String categoryId, required String subcategoryId}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLastCategoryId, categoryId);
    await sp.setString(_kLastSubcategoryId, subcategoryId);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kLastCategoryId);
    await sp.remove(_kLastSubcategoryId);
  }
}
