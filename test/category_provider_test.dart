import 'package:expense_tracking_prd/core/network/api_client.dart';
import 'package:expense_tracking_prd/models/category_model.dart';
import 'package:expense_tracking_prd/repositories/category_repository.dart';
import 'package:expense_tracking_prd/state/category_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ServerCategoryRepository extends CategoryRepository {
  CategoryModel? lastUpdated;
  String? removedId;

  _ServerCategoryRepository()
    : super(ApiClient(baseUrl: 'https://example.invalid'));

  @override
  Future<List<CategoryModel>> getCategories() async => const [
    CategoryModel(
      id: 'server-category-z',
      name: 'Work Meals',
      iconName: 'meal',
    ),
    CategoryModel(
      id: 'server-category-1',
      name: 'Transportation',
      iconName: 'transport',
    ),
  ];

  @override
  Future<CategoryModel> createCategory(CategoryModel category) async =>
      CategoryModel(
        id: 'server-category-2',
        name: category.name,
        iconName: category.iconName,
      );

  @override
  Future<CategoryModel> updateCategory(CategoryModel category) async {
    lastUpdated = category;
    return category;
  }

  @override
  Future<CategoryModel> setCategoryActive(String id, bool isActive) async {
    lastUpdated = CategoryModel(
      id: id,
      name: 'Work Meals',
      iconName: 'meal',
      isActive: isActive,
    );
    return lastUpdated!;
  }

  @override
  Future<CategoryModel> removeCategory(String id) async {
    removedId = id;
    return const CategoryModel(
      id: 'server-category-z',
      name: 'Work Meals',
      iconName: 'meal',
      isActive: false,
    );
  }
}

void main() {
  test(
    'loads server category IDs and stores the ID returned when creating a category',
    () async {
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            _ServerCategoryRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(categoryProvider.notifier);
      expect(await notifier.fetchCategories(), isTrue);
      expect(container.read(categoryProvider).map((category) => category.id), [
        'server-category-1',
        'server-category-z',
      ]);

      await notifier.addCategory('Meals', 'meal');
      expect(container.read(categoryProvider).map((category) => category.id), [
        'server-category-1',
        'server-category-2',
        'server-category-z',
      ]);
    },
  );

  test('persists activation and removal through the server', () async {
    final repository = _ServerCategoryRepository();
    final container = ProviderContainer(
      overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(categoryProvider.notifier);
    await notifier.fetchCategories();

    await notifier.setCategoryActive('server-category-z', false);
    expect(repository.lastUpdated?.isActive, isFalse);
    await notifier.removeCategory('server-category-z');
    expect(repository.removedId, 'server-category-z');
  });
}
