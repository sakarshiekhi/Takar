import 'package:flutter/material.dart';

class ProgressCircle extends StatefulWidget {
  final double progress;
  final VoidCallback onComplete;
  final double tickSize;
  final Color completedColor;
  final bool isCompleted;

  const ProgressCircle({
    super.key,
    required this.progress,
    required this.onComplete,
    this.tickSize = 32.0,
    this.completedColor = Colors.deepPurple,
    required this.isCompleted,
  });

  @override
  _ProgressCircleState createState() => _ProgressCircleState();
}

class _ProgressCircleState extends State<ProgressCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _controller.addListener(() {
      if (_controller.isCompleted) {
        widget.onComplete();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProgressCircle oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.progress >= 1.0 && !oldWidget.isCompleted) {
      _controller.forward();
    } else if (widget.progress < 1.0 && _controller.isCompleted) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: 50,
        height: 50,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: widget.isCompleted ? 1.0 : widget.progress,
              strokeWidth: 4.0,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.deepPurple,
              ),
            ),
            if (widget.isCompleted)
              ScaleTransition(
                scale: _controller,
                child: Icon(
                  Icons.check,
                  color: widget.completedColor,
                  size: widget.tickSize,
                  
                ),
              ),
          ],
        ),
      ),
    );
  }
}
