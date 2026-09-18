import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class CategoryDropdown extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<CategoryModel?> onChanged;
  final String? Function(String?)? validator;

  const CategoryDropdown({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
    this.validator,
  });

  IconData _getIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'travel':
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'meal':
      case 'food':
        return Icons.restaurant_rounded;
      case 'lodging':
      case 'hotel':
        return Icons.hotel_rounded;
      case 'hardware':
      case 'tech':
        return Icons.laptop_mac_rounded;
      case 'software':
      case 'subscription':
        return Icons.apps_rounded;
      case 'transport':
      case 'taxi':
        return Icons.local_taxi_rounded;
      case 'office':
      case 'supplies':
        return Icons.business_center_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = categories.where((c) => c.isActive).toList();

    return DropdownButtonFormField<String>(
      value: selectedCategoryId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Expense Category *',
        hintText: 'Select category',
      ),
      validator: validator ??
          (val) {
            if (val == null || val.isEmpty) {
              return 'Please select an expense category';
            }
            return null;
          },
      items: activeCategories.map((cat) {
        return DropdownMenuItem<String>(
          value: cat.id,
          child: Row(
            children: [
              Icon(_getIcon(cat.iconName), size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(cat.name, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        );
      }).toList(),
      onChanged: (id) {
        if (id == null) {
          onChanged(null);
        } else {
          final cat = activeCategories.firstWhere((c) => c.id == id);
          onChanged(cat);
        }
      },
    );
  }
}
