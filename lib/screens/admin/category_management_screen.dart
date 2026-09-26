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
    showDialog(
      context: context,
      builder: (ctx) => _CategoryAddEditDialog(existing: existing, getIcon: _getIcon),
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
        backgroundColor: AppColors.getPrimary(context),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
            itemCount: categories.length,
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final isDark = Theme.of(ctx).brightness == Brightness.dark;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cat.isActive
                      ? AppColors.getSurface(context)
                      : (isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: isDark ? [] : AppColors.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.getPrimary(context).withValues(alpha: 0.16) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getIcon(cat.iconName), color: AppColors.getPrimary(context), size: 20),
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
                      activeTrackColor: AppColors.emerald,
                      onChanged: (_) {
                        ref.read(categoryProvider.notifier).toggleActive(cat.id);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryAddEditDialog extends ConsumerStatefulWidget {
  final CategoryModel? existing;
  final IconData Function(String) getIcon;

  const _CategoryAddEditDialog({
    this.existing,
    required this.getIcon,
  });

  @override
  ConsumerState<_CategoryAddEditDialog> createState() => _CategoryAddEditDialogState();
}

class _CategoryAddEditDialogState extends ConsumerState<_CategoryAddEditDialog> {
  late final TextEditingController _controller;
  late String _selectedIcon;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.name ?? '');
    _selectedIcon = widget.existing?.iconName ?? 'office';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;

    return AlertDialog(
      title: Text(
        existing == null ? 'Add New Category' : 'Rename Category',
        style: AppTextStyles.titleMedium,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _controller,
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
                final isSel = _selectedIcon == iconKey;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = iconKey),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.primary : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.getIcon(iconKey),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final name = _controller.text.trim();
              if (existing == null) {
                ref.read(categoryProvider.notifier).addCategory(name, _selectedIcon);
                NotificationBanner.showSuccess(context, 'Category "$name" created.');
              } else {
                ref.read(categoryProvider.notifier).updateCategory(existing.id, name, _selectedIcon);
                NotificationBanner.showSuccess(context, 'Category updated.');
              }
              Navigator.pop(context);
            }
          },
          child: const Text('Save Category'),
        ),
      ],
    );
  }
}
