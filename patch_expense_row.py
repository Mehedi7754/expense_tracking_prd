with open('lib/core/widgets/expense_list_row.dart', 'r') as f:
    content = f.read()

target = """                      Text(
                        showEmployeeName ? expense.employeeName : expense.projectName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        showEmployeeName
                            ? '${expense.projectName} • ${expense.categoryName} • ${DateFormatter.formatShort(expense.date)}${expense.hasTax ? ' • Inc. ${expense.taxRate.toStringAsFixed(expense.taxRate.truncateToDouble() == expense.taxRate ? 0 : 1)}% Tax' : ''}'
                            : '${expense.categoryName} • ${DateFormatter.formatShort(expense.date)}${expense.hasTax ? ' • Inc. ${expense.taxRate.toStringAsFixed(expense.taxRate.truncateToDouble() == expense.taxRate ? 0 : 1)}% Tax' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                      if (expense.note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          expense.note,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],"""

replacement = """                      Text(
                        showEmployeeName ? expense.employeeName : expense.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        showEmployeeName
                            ? '${expense.projectName} • ${expense.categoryName} • ${DateFormatter.formatShort(expense.date)}${expense.hasTax ? ' • Inc. ${expense.taxRate.toStringAsFixed(expense.taxRate.truncateToDouble() == expense.taxRate ? 0 : 1)}% Tax' : ''}'
                            : '${expense.categoryName} • ${DateFormatter.formatShort(expense.date)}${expense.hasTax ? ' • Inc. ${expense.taxRate.toStringAsFixed(expense.taxRate.truncateToDouble() == expense.taxRate ? 0 : 1)}% Tax' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                      if (expense.note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          expense.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],"""

content = content.replace(target, replacement)
with open('lib/core/widgets/expense_list_row.dart', 'w') as f:
    f.write(content)
print("Patched ExpenseListRow")
