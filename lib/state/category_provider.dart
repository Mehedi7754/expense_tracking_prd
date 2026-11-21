import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../repositories/category_repository.dart';

class CategoryNotifier extends Notifier<List<CategoryModel>> {
  bool _hasLoadedFromServer = false;
  Future<bool>? _loadInProgress;

  @override
  List<CategoryModel> build() {
    // Categories must use server IDs; local placeholder IDs cannot be used by
    // expense update endpoints, which validate the category foreign key.
    scheduleMicrotask(() => fetchCategories());
    return const [];
  }

  Future<bool> fetchCategories({bool force = false}) {
    if (_hasLoadedFromServer && !force) return Future.value(true);
    if (_loadInProgress != null) return _loadInProgress!;
    final load = _loadCategories();
    _loadInProgress = load;
    return load.whenComplete(() => _loadInProgress = null);
  }

  Future<bool> _loadCategories() async {
    try {
      final categories =
          await ref.read(categoryRepositoryProvider).getCategories();
      state = _ordered(categories);
      _hasLoadedFromServer = true;
      return true;
    } catch (_) {
      // Leave the category list empty rather than offering fake IDs that the
      // backend cannot persist.
      state = const [];
      return false;
    }
  }

  Future<void> addCategory(String name, String iconName) async {
    final created = await ref
        .read(categoryRepositoryProvider)
        .createCategory(CategoryModel(id: '', name: name, iconName: iconName));
    state = _ordered([...state, created]);
  }

  Future<void> setCategoryActive(String id, bool isActive) async {
    final saved = await ref
        .read(categoryRepositoryProvider)
        .setCategoryActive(id, isActive);
    _replace(saved);
  }

  Future<void> removeCategory(String id) async {
    final saved = await ref.read(categoryRepositoryProvider).removeCategory(id);
    _replace(saved);
  }

  Future<void> updateCategory(
    String id,
    String newName,
    String newIconName,
  ) async {
    final index = state.indexWhere((category) => category.id == id);
    if (index < 0)
      throw StateError(
        'Category is no longer available. Refresh and try again.',
      );
    final updated = state[index].copyWith(name: newName, iconName: newIconName);
    final saved = await ref
        .read(categoryRepositoryProvider)
        .updateCategory(updated);
    _replace(saved);
  }

  void _replace(CategoryModel saved) {
    state = _ordered([
      for (final category in state)
        if (category.id == saved.id) saved else category,
    ]);
  }

  List<CategoryModel> _ordered(List<CategoryModel> categories) {
    final result = [...categories];
    result.sort((a, b) {
      final aTransportation = a.name.trim().toLowerCase() == 'transportation';
      final bTransportation = b.name.trim().toLowerCase() == 'transportation';
      if (aTransportation != bTransportation) return aTransportation ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }
}

final categoryProvider =
    NotifierProvider<CategoryNotifier, List<CategoryModel>>(
      CategoryNotifier.new,
    );
