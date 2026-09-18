class CategoryModel {
  final String id;
  final String name;
  final String iconName; // Identifies icon in app
  final bool isDefault;
  final bool isActive;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconName,
    this.isDefault = false,
    this.isActive = true,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    String? iconName,
    bool? isDefault,
    bool? isActive,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
    );
  }
}
