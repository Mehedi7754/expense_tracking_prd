with open('lib/screens/attendance/widgets/attendance_map_view.dart', 'r') as f:
    content = f.read()

target = """              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Morning Session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Afternoon Session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),"""

replacement = """              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4F46E5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Morning Session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Afternoon Session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),"""

content = content.replace(target, replacement)
with open('lib/screens/attendance/widgets/attendance_map_view.dart', 'w') as f:
    f.write(content)
print("Patched map legend in attendance_map_view.dart")
