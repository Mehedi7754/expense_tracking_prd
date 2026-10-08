import re

with open('lib/screens/expenses/submit_expense_screen.dart', 'r') as f:
    content = f.read()

# Replace the onPressed block of the cross sign
old_onpressed = """                              onPressed: () => setState(() {
                                _receiptFileName = null;
                                _receiptPath = null;
                              }),"""

new_onpressed = """                              onPressed: () => setState(() {
                                _receiptFileName = null;
                                _receiptPath = null;
                                _hasReceipt = false; // Turn off the toggle automatically when receipt is removed
                              }),"""

if old_onpressed in content:
    content = content.replace(old_onpressed, new_onpressed)
    with open('lib/screens/expenses/submit_expense_screen.dart', 'w') as f:
        f.write(content)
    print("Patched successfully")
else:
    print("Could not find the target code")

