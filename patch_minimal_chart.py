with open('lib/core/widgets/minimal_area_chart.dart', 'r') as f:
    content = f.read()

target = """                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (widget.onTap != null) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                  color: Color(0xFF4F46E5),
                                ),
                              ],
                            ],
                          ),"""

replacement = """                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (widget.onTap != null) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                  color: Color(0xFF4F46E5),
                                ),
                              ],
                            ],
                          ),"""

if target in content:
    content = content.replace(target, replacement)
    with open('lib/core/widgets/minimal_area_chart.dart', 'w') as f:
        f.write(content)
    print("Replaced successfully")
else:
    print("Target not found")
