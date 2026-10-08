with open('lib/core/widgets/stat_card.dart', 'r') as f:
    content = f.read()

target = """                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11,
                    color: AppColors.getTextMuted(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),"""

replacement = """                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11,
                    color: AppColors.getTextMuted(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),"""

content = content.replace(target, replacement)
with open('lib/core/widgets/stat_card.dart', 'w') as f:
    f.write(content)
print("Patched StatCard")
