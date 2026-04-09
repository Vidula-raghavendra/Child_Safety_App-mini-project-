import 'package:flutter/material.dart';

class SOSButton extends StatefulWidget {
  const SOSButton({super.key});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => setState(() => _isPressed = true),
      onLongPressEnd: (_) => setState(() => _isPressed = false),
      onLongPress: () {
        // Trigger SOS
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS Alert Sent!'), backgroundColor: Colors.red),
        );
      },
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.1).animate(_controller),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(color: Colors.white, width: 6),
          ),
          child: const Center(
            child: Text(
              'SOS',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.black),
            ),
          ),
        ),
      ),
    );
  }
}
