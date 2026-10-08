with open('lib/core/widgets/stat_card.dart', 'r') as f:
    content = f.read()

target = """        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context), width: 1),
          boxShadow: isDark ? AppColors.darkCardShadow(iconColor) : AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ["""

replacement = """        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context), width: 1),
          boxShadow: isDark ? AppColors.darkCardShadow(iconColor) : AppColors.cardShadow,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ["""

content = content.replace(target, replacement)
content = content.replace("          ],\n        ),\n      ),\n    );", "          ],\n            ),\n          ),\n        ),\n      ),\n    );")

with open('lib/core/widgets/stat_card.dart', 'w') as f:
    f.write(content)
print("Patched StatCard 2")
