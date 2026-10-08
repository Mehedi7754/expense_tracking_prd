with open('lib/screens/projects/project_detail_screen.dart', 'r') as f:
    content = f.read()

target = """        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor,
          ),
        ),"""

replacement = """        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isBold ? 15 : 13,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ),"""

content = content.replace(target, replacement)
with open('lib/screens/projects/project_detail_screen.dart', 'w') as f:
    f.write(content)
print("Patched _buildForecastItem in project_detail_screen.dart")
