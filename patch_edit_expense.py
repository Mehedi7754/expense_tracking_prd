import re

with open('lib/screens/expenses/edit_expense_screen.dart', 'r') as f:
    content = f.read()

new_validation = """
    if (_selectedProject == null || _selectedCategory == null) {
      NotificationBanner.showError(context, 'Please ensure all required fields are chosen');
      return;
    }

    if (_exceedsThresholdWithoutReceipt) {
      NotificationBanner.showError(context, 'Receipt required for expenses above threshold');
      return;
    }

    if ((_receiptImagePath == null || _receiptImagePath!.isEmpty) && _noteController.text.trim().isEmpty) {
      NotificationBanner.showError(context, 'A justification is required in the Note field when saving without a receipt.');
      return;
    }
"""

content = content.replace("""
    if (_selectedProject == null || _selectedCategory == null) {
      NotificationBanner.showError(context, 'Please ensure all required fields are chosen');
      return;
    }
""", new_validation)

with open('lib/screens/expenses/edit_expense_screen.dart', 'w') as f:
    f.write(content)
print("Patched successfully")
