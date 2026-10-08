with open('test/notification_feature_test.dart', 'r') as f:
    content = f.read()

import_line = "import 'package:shared_preferences/shared_preferences.dart';\n"
if "package:shared_preferences/shared_preferences.dart" not in content:
    content = import_line + content

setup_code = """
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
"""

content = content.replace("void main() {", "void main() {" + setup_code)

with open('test/notification_feature_test.dart', 'w') as f:
    f.write(content)
print("Added SharedPreferences mock to test/notification_feature_test.dart")
