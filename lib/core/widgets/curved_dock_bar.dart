import 'dart:math';
import 'package:flutter/material.dart';

typedef LetIndexPage = bool Function(int value);

class CurvedDockBar extends StatefulWidget {
  final List<Widget> items;
  final int index;
  final Color color;
  final Color? buttonBackgroundColor;
  final Color backgroundColor;
  final ValueChanged<int>? onTap;
  final LetIndexPage letIndexChange;
  final Curve animationCurve;
  final Duration animationDuration;
  final double height;
  final double? maxWidth;
  final double cornerRadius;

  CurvedDockBar({
    super.key,
    required this.items,
    this.index = 0,
    this.color = const Color(0xFFEA580C),
    this.buttonBackgroundColor,
    this.backgroundColor = Colors.transparent,
    this.onTap,
    LetIndexPage? letIndexChange,
    this.animationCurve = Curves.easeInOutCubic,
    this.animationDuration = const Duration(milliseconds: 320),
    this.height = 54.0,
    this.maxWidth,
    this.cornerRadius = 20.0,
  })  : letIndexChange = letIndexChange ?? ((_) => true),
        assert(items.isNotEmpty),
        assert(0 <= index && index < items.length),
        assert(0 <= height && height <= 85.0),
        assert(maxWidth == null || 0 <= maxWidth);

  @override
  CurvedDockBarState createState() => CurvedDockBarState();
}

class CurvedDockBarState extends State<CurvedDockBar>
    with SingleTickerProviderStateMixin {
  late double _startingPos;
  late int _endingIndex;
  late double _pos;
  double _buttonHide = 0;
  late Widget _icon;
  late AnimationController _animationController;
  late int _length;

  @override
  void initState() {
    super.initState();
    _icon = widget.items[widget.index];
    _length = widget.items.length;
    _pos = widget.index / _length;
    _startingPos = widget.index / _length;
    _endingIndex = widget.index;
    _animationController = AnimationController(vsync: this, value: _pos);
    _animationController.addListener(() {
      setState(() {
        _pos = _animationController.value;
        final endingPos = _endingIndex / widget.items.length;
        final middle = (endingPos + _startingPos) / 2;
        if ((endingPos - _pos).abs() < (_startingPos - _pos).abs()) {
          _icon = widget.items[_endingIndex];
        }
        _buttonHide =
            (1 - ((middle - _pos) / (_startingPos - middle)).abs()).abs();
      });
    });
  }

  @override
  void didUpdateWidget(CurvedDockBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      final newPosition = widget.index / _length;
      _startingPos = _pos;
      _endingIndex = widget.index;
      _animationController.animateTo(
        newPosition,
        duration: widget.animationDuration,
        curve: widget.animationCurve,
      );
    }
    if (!_animationController.isAnimating) {
      _icon = widget.items[_endingIndex];
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    const baseHeight = 60.0;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = min(
            constraints.maxWidth,
            widget.maxWidth ?? constraints.maxWidth,
          );
          return Align(
            alignment: textDirection == TextDirection.ltr
                ? Alignment.bottomLeft
                : Alignment.bottomRight,
            child: Container(
              color: widget.backgroundColor,
              width: maxWidth,
              child: ClipRect(
                clipper: _DockCustomClipper(
                  deviceHeight: MediaQuery.sizeOf(context).height,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    // Dock body with curved upper side corners
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0 - (baseHeight - widget.height),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(widget.cornerRadius),
                          topRight: Radius.circular(widget.cornerRadius),
                        ),
                        child: CustomPaint(
                          painter: _DockCustomPainter(
                            _pos,
                            _length,
                            widget.color,
                            textDirection,
                          ),
                          child: const SizedBox(
                            height: baseHeight,
                          ),
                        ),
                      ),
                    ),
                    // Navigation bar icons
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0 - (baseHeight - widget.height),
                      child: SizedBox(
                        height: baseHeight,
                        child: Row(
                          children: widget.items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return _DockNavButton(
                              onTap: _buttonTap,
                              position: _pos,
                              length: _length,
                              index: idx,
                              child: Center(child: item),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    // Elevated floating circular button with rich contrast & shadow
                    Positioned(
                      bottom: -28 - (baseHeight - widget.height),
                      left: textDirection == TextDirection.rtl
                          ? null
                          : _pos * maxWidth,
                      right: textDirection == TextDirection.rtl
                          ? _pos * maxWidth
                          : null,
                      width: maxWidth / _length,
                      child: Center(
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            -(1 - _buttonHide) * 58,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: widget.buttonBackgroundColor ?? Colors.white,
                              elevation: 0,
                              shape: CircleBorder(
                                side: BorderSide(
                                  color: widget.color.withValues(alpha: 0.12),
                                  width: 1.2,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _buttonTap(_endingIndex),
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(9.0),
                                  child: _icon,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void setPage(int index) {
    _buttonTap(index);
  }

  void _buttonTap(int index) {
    if (!widget.letIndexChange(index) || _animationController.isAnimating) {
      return;
    }
    if (widget.onTap != null) {
      widget.onTap!(index);
    }
    final newPosition = index / _length;
    setState(() {
      _startingPos = _pos;
      _endingIndex = index;
      _animationController.animateTo(
        newPosition,
        duration: widget.animationDuration,
        curve: widget.animationCurve,
      );
    });
  }
}

class _DockNavButton extends StatelessWidget {
  final double position;
  final int length;
  final int index;
  final ValueChanged<int> onTap;
  final Widget child;

  const _DockNavButton({
    required this.onTap,
    required this.position,
    required this.length,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final desiredPosition = 1.0 / length * index;
    final difference = (position - desiredPosition).abs();
    final verticalAlignment = 1 - length * difference;
    final opacity = length * difference;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: SizedBox(
          height: 60.0,
          child: Transform.translate(
            offset: Offset(
              0,
              difference < 1.0 / length ? verticalAlignment * 30 : 0,
            ),
            child: Opacity(
              opacity: difference < 1.0 / length * 0.9
                  ? ((opacity - 0.1) < 0 ? 0 : (opacity - 0.1))
                  : 1.0,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _DockCustomClipper extends CustomClipper<Rect> {
  final double deviceHeight;

  _DockCustomClipper({required this.deviceHeight});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      0,
      -deviceHeight + size.height,
      size.width,
      deviceHeight,
    );
  }

  @override
  bool shouldReclip(_DockCustomClipper oldClipper) {
    return oldClipper.deviceHeight != deviceHeight;
  }
}

class _DockCustomPainter extends CustomPainter {
  late double loc;
  late double s;
  final Color color;
  final TextDirection textDirection;

  _DockCustomPainter(
    double startingLoc,
    int itemsLength,
    this.color,
    this.textDirection,
  ) {
    final span = 1.0 / itemsLength;
    s = 0.2;
    double l = startingLoc + (span - s) / 2;
    loc = textDirection == TextDirection.rtl ? 0.8 - l : l;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo((loc - 0.1) * size.width, 0)
      ..cubicTo(
        (loc + s * 0.20) * size.width,
        size.height * 0.05,
        loc * size.width,
        size.height * 0.60,
        (loc + s * 0.50) * size.width,
        size.height * 0.60,
      )
      ..cubicTo(
        (loc + s) * size.width,
        size.height * 0.60,
        (loc + s - s * 0.20) * size.width,
        size.height * 0.05,
        (loc + s + 0.1) * size.width,
        0,
      )
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black.withAlpha(24), 8, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DockCustomPainter oldDelegate) {
    return oldDelegate.loc != loc || oldDelegate.color != color;
  }
}
