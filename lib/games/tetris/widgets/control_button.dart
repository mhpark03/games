import 'package:flutter/material.dart';

class ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  const ControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade600, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}

class HoldControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Duration initialDelay;
  final Duration repeatInterval;

  const HoldControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 60,
    this.initialDelay = const Duration(milliseconds: 200),
    this.repeatInterval = const Duration(milliseconds: 50),
  });

  @override
  State<HoldControlButton> createState() => _HoldControlButtonState();
}

class _HoldControlButtonState extends State<HoldControlButton> {
  bool _isPressed = false;

  void _startHold() {
    _isPressed = true;
    widget.onPressed();
    _scheduleRepeat();
  }

  void _scheduleRepeat() async {
    await Future.delayed(widget.initialDelay);
    while (_isPressed) {
      widget.onPressed();
      await Future.delayed(widget.repeatInterval);
    }
  }

  void _stopHold() {
    _isPressed = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _stopHold(),
      onTapCancel: () => _stopHold(),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade600, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Icon(
          widget.icon,
          color: Colors.white,
          size: widget.size * 0.5,
        ),
      ),
    );
  }
}
