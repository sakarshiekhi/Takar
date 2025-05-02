import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

class ProgressCircle extends StatefulWidget {
  final double progress;
  final VoidCallback onComplete;
  final double tickSize; // Added tickSize parameter
  final Color completedColor; // Added completedColor parameter

  const ProgressCircle({
    super.key,
    required this.progress,
    required this.onComplete,
    this.tickSize = 32.0, // Default tick size
    this.completedColor = Colors.green, // Default completed color
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
      duration: const Duration(seconds: 1),
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
    if (widget.progress == 1.0) {
      _controller.forward();
    } else {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 24, // Smaller size
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: widget.progress,
                strokeWidth: 2.0, // Thinner stroke
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  widget.progress == 1.0 ? Colors.green : Colors.blue[300],
                ),
              ),
              if (widget.progress == 1.0)
                ScaleTransition(
                  scale: _controller,
                  child: Icon(
                    Icons.check,
                    color: widget.completedColor,
                    size: widget.tickSize * 0.8, // Smaller checkmark
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
