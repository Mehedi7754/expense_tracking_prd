with open('test/responsive_layout_test.dart', 'r') as f:
    content = f.read()

target = """    // Tap on minimal category card to expand dropdown
    final equipCard = find.text('Equipment').first;
    await tester.ensureVisible(equipCard);
    await tester.tap(equipCard, warnIfMissed: false);"""

replacement = """    // Tap on minimal category card to expand dropdown
    final equipCard = find.text('Equipment').last;
    await tester.ensureVisible(equipCard);
    await tester.tap(equipCard);"""

content = content.replace(target, replacement)
with open('test/responsive_layout_test.dart', 'w') as f:
    f.write(content)
print("Patched equipCard to .last")
