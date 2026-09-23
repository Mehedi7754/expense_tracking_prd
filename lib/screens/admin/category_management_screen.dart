import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/category_model.dart';
import '../../state/category_provider.dart';

class CategoryManagementScreen extends ConsumerWidget {
  final bool isEmbedded;

  const CategoryManagementScreen({
    super.key,
    this.isEmbedded = false,
  });

  IconData _getIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'meal':
        return Icons.restaurant_rounded;
      case 'lodging':
        return Icons.hotel_rounded;
      case 'hardware':
        return Icons.laptop_mac_rounded;
      case 'software':
        return Icons.apps_rounded;
      case 'transport':
        return Icons.local_taxi_rounded;
      case 'office':
        return Icons.business_center_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  void _showAddEditDialog(BuildContext context, WidgetRef ref, [CategoryModel? existing]) {
    final controller = TextEditingController(text: existing?.name ?? '');
    String selectedIcon = existing?.iconName ?? 'office';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Add New Category' : 'Rename Category',
            style: AppTextStyles.titleMedium,
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Category Title *',
                    hintText: 'e.g. Client Entertainment, Training...',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Title required' : null,
                ),
                const SizedBox(height: 16),
                Text('Category Icon', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'travel',
                    'meal',
                    'lodging',
                    'hardware',
                    'software',
                    'transport',
                    'office',
                  ].map((iconKey) {
                    final isSel = selectedIcon == iconKey;
                    return InkWell(
                      onTap: () => setModalState(() => selectedIcon = iconKey),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primary : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getIcon(iconKey),
                          size: 20,
                          color: isSel ? AppColors.textWhite : AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final name = controller.text.trim();
                  if (existing == null) {
                    ref.read(categoryProvider.notifier).addCategory(name, selectedIcon);
                    NotificationBanner.showSuccess(context, 'Category "$name" created.');
                  } else {
                    ref.read(categoryProvider.notifier).updateCategory(existing.id, name, selectedIcon);
                    NotificationBanner.showSuccess(context, 'Category updated.');
                  }
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Category'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: isEmbedded
          ? null
          : AppBar(
              title: const Text('Category Management'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Add Category',
                  onPressed: () => _showAddEditDialog(context, ref),
                ),
                const SizedBox(width: 8),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_add_category_fab',
        onPressed: () => _showAddEditDialog(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final cat = categories[i];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cat.isActive ? AppColors.surface : AppColors.surfaceSubtle.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cat.isActive ? AppColors.surfaceSubtle : AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getIcon(cat.iconName), color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              cat.name,
                              style: AppTextStyles.titleSmall.copyWith(
                                decoration: cat.isActive ? null : TextDecoration.lineThrough,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (cat.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'System Default',
                                style: AppTextStyles.labelSmall.copyWith(fontSize: 9.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        cat.isActive ? 'Active for claim submission' : 'Inactive (Hidden from users)',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Rename Category',
                  onPressed: () => _showAddEditDialog(context, ref, cat),
                ),
                Switch(
                  value: cat.isActive,
                  activeColor: AppColors.emerald,
                  onChanged: (_) {
                    ref.read(categoryProvider.notifier).toggleActive(cat.id);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
