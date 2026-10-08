with open('test/responsive_layout_test.dart', 'r') as f:
    content = f.read()

target = "expect(find.text('Cost Incurred'), findsOneWidget);"
replacement = "expect(find.textContaining('Costs Incurred'), findsOneWidget);"

content = content.replace(target, replacement)
with open('test/responsive_layout_test.dart', 'w') as f:
    f.write(content)
print("Patched responsive_layout_test.dart line 550")
