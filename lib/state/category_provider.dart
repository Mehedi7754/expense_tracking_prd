import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../repositories/category_repository.dart';

class CategoryNotifier extends Notifier<List<CategoryModel>> {
  static const List<CategoryModel> _defaultCategories = [
    CategoryModel(id: 'cat_travel', name: 'Travel & Flights', iconName: 'travel', isDefault: true, isActive: true),
    CategoryModel(id: 'cat_meals', name: 'Meals & Dining', iconName: 'meal', isDefault: true, isActive: true),
    CategoryModel(id: 'cat_lodging', name: 'Lodging & Hotels', iconName: 'lodging', isDefault: true, isActive: true),
    CategoryModel(id: 'cat_hardware', name: 'Hardware & Devices', iconName: 'hardware', isDefault: true, isActive: true),
    CategoryModel(id: 'cat_software', name: 'Software & Tools', iconName: 'software', isDefault: true, isActive: true),
    CategoryModel(id: 'cat_transport', name: 'Ground Transport & Taxi', iconName: 'transport', isDefault: true, isActive: true),
    CategoryModel(id: 'cat_office', name: 'Office & Supplies', iconName: 'office', isDefault: true, isActive: true),
  ];

  @override
  List<CategoryModel> build() => _defaultCategories;

  Future<void> fetchCategories() async {
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final categories = await repo.getCategories();
      if (categories.isNotEmpty) {
        state = categories;
      }
    } catch (_) {
      // Keep defaults
    }
  }

  void toggleActive(String id) {
    state = [
      for (final cat in state)
        if (cat.id == id) cat.copyWith(isActive: !cat.isActive) else cat,
    ];
  }

  Future<void> addCategory(String name, String iconName) async {
    final newCat = CategoryModel(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      iconName: iconName,
      isDefault: false,
      isActive: true,
    );
    state = [...state, newCat];

    try {
      final repo = ref.read(categoryRepositoryProvider);
      await repo.createCategory(newCat);
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> updateCategory(String id, String newName, String newIconName) async {
    state = [
      for (final cat in state)
        if (cat.id == id) cat.copyWith(name: newName, iconName: newIconName) else cat,
    ];

    final updated = state.firstWhere((c) => c.id == id);
    try {
      final repo = ref.read(categoryRepositoryProvider);
      await repo.updateCategory(updated);
    } catch (_) {
      // Offline fallback
    }
  }
}

final categoryProvider = NotifierProvider<CategoryNotifier, List<CategoryModel>>(CategoryNotifier.new);
