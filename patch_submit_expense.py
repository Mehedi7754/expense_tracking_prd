import re

with open('lib/screens/expenses/submit_expense_screen.dart', 'r') as f:
    content = f.read()

new_validation = """
    if (_currentAmount <= 0) {
      NotificationBanner.showError(context, 'Please enter a valid expense amount');
      return;
    }

    final localReceiptPath = _receiptPath ?? _receiptFileName;

    if (_hasReceipt && (localReceiptPath == null || localReceiptPath.isEmpty)) {
      NotificationBanner.showError(context, 'Please attach a receipt image or turn off the receipt toggle.');
      return;
    }

    if (!_hasReceipt && _noteController.text.trim().isEmpty) {
      NotificationBanner.showError(context, 'A justification is required in the Note field when submitting without a receipt.');
      return;
    }
"""

content = content.replace("""
    if (_currentAmount <= 0) {
      NotificationBanner.showError(context, 'Please enter a valid expense amount');
      return;
    }
""", new_validation)

# Also update the Note field to show it's required if no receipt
new_note_field = """
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: _hasReceipt ? 'Note / Description (Optional)' : 'Note / Justification (Required)',
                      alignLabelWithHint: true,
"""

content = re.sub(r"""                  TextFormField\(\s*controller: _noteController,\s*maxLines: 3,\s*decoration: const InputDecoration\(\s*labelText: 'Note / Description \(Optional\)',\s*alignLabelWithHint: true,""", new_note_field, content)


with open('lib/screens/expenses/submit_expense_screen.dart', 'w') as f:
    f.write(content)
