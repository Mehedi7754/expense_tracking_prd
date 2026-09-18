import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';

class CategoryNotifier extends Notifier<List<CategoryModel>> {
  static final List<CategoryModel> _initialCategories = [
    const CategoryModel(
      id: 'cat_01',
      name: 'Travel & Flights',
      iconName: 'travel',
      isDefault: true,
      isActive: true,
    ),
    const CategoryModel(
      id: 'cat_02',
      name: 'Meals & Dining',
      iconName: 'meal',
      isDefault: true,
      isActive: true,
    ),
    const CategoryModel(
      id: 'cat_03',
      name: 'Lodging & Hotels',
      iconName: 'lodging',
      isDefault: true,
      isActive: true,
    ),
    const CategoryModel(
      id: 'cat_04',
      name: 'Hardware & Devices',
      iconName: 'hardware',
      isDefault: true,
      isActive: true,
    ),
    const CategoryModel(
      id: 'cat_05',
      name: 'Software & Tools',
      iconName: 'software',
      isDefault: true,
      isActive: true,
    ),
    const CategoryModel(
      id: 'cat_06',
      name: 'Ground Transport & Taxi',
      iconName: 'transport',
      isDefault: true,
      isActive: true,
    ),
    const CategoryModel(
      id: 'cat_07',
      name: 'Office & Supplies',
      iconName: 'office',
      isDefault: true,
      isActive: true,
    ),
  ];

  @override
  List<CategoryModel> build() => _initialCategories;

  void toggleActive(String id) {
    state = [
      for (final cat in state)
        if (cat.id == id) cat.copyWith(isActive: !cat.isActive) else cat,
    ];
  }

  void addCategory(String name, String iconName) {
    final newCat = CategoryModel(
      id: 'cat_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      iconName: iconName,
      isDefault: false,
      isActive: true,
    );
    state = [...state, newCat];
  }

  void updateCategory(String id, String newName, String newIconName) {
    state = [
      for (final cat in state)
        if (cat.id == id) cat.copyWith(name: newName, iconName: newIconName) else cat,
    ];
  }
}

final categoryProvider = NotifierProvider<CategoryNotifier, List<CategoryModel>>(CategoryNotifier.new);
