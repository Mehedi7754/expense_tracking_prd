with open('test/responsive_layout_test.dart', 'r') as f:
    content = f.read()

target = """    // Switch to Categories tab
    final categoriesTab = find.textContaining('Categories');
    expect(categoriesTab, findsOneWidget);
    await tester.ensureVisible(categoriesTab);
    await tester.tap(categoriesTab);
    await tester.pumpAndSettle();

    // Tap on minimal category card to expand dropdown
    final equipCard = find.text('Equipment').last;
    await tester.ensureVisible(equipCard);
    await tester.tap(equipCard);
    await tester.pumpAndSettle();
    expect(find.text('Claimants in this category:'), findsWidgets);"""

replacement = """    // Switch to Categories tab
    final categoriesTab = find.textContaining('Categories');
    expect(categoriesTab, findsOneWidget);
    await tester.ensureVisible(categoriesTab);
    await tester.tap(categoriesTab);
    await tester.pumpAndSettle();

    // Scroll up slightly inside the modal so category card is within view
    await tester.drag(find.byType(ListView).last, const Offset(0, -150));
    await tester.pumpAndSettle();

    // Tap on minimal category card to expand dropdown
    final equipCard = find.text('Equipment').last;
    await tester.tap(equipCard, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Claimants in this category:'), findsWidgets);"""

content = content.replace(target, replacement)
with open('test/responsive_layout_test.dart', 'w') as f:
    f.write(content)
print("Patched scroll in modal for Categories tab")
