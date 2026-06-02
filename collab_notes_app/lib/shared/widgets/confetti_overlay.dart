import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final ConfettiController controller;

  const ConfettiOverlay({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: widget.controller,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            emissionFrequency: 0.06,
            numberOfParticles: 25,
            maxBlastForce: 30,
            minBlastForce: 10,
            gravity: 0.2,
            particleDrag: 0.05,
            colors: const [
              Color(0xFFFF6B6B),
              Color(0xFFFFD43B),
              Color(0xFF69DB7C),
              Color(0xFF4DABF7),
              Color(0xFF9775FA),
              Color(0xFFDA77F2),
              Color(0xFFF783AC),
              Color(0xFF20C997),
              Color(0xFFF59F00),
              Color(0xFF748FFC),
            ],
          ),
        ),
      ],
    );
  }
}
