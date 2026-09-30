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

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      iconName: (json['icon_name'] ?? json['iconName'] ?? 'category').toString(),
      isDefault: json['is_default'] ?? json['isDefault'] ?? false,
      isActive: json['is_active'] ?? json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_name': iconName,
      'is_default': isDefault,
      'is_active': isActive,
    };
  }
}
