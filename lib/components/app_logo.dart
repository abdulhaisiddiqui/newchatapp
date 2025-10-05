import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 60, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Icon
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
            ),
            borderRadius: BorderRadius.circular(size * 0.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withValues(alpha: 0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.chat_bubble, color: Colors.white, size: size * 0.5),
        ),

        if (showText) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ChatApp',
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1976D2),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Connect & Share',
                style: TextStyle(
                  fontSize: size * 0.2,
                  color: const Color(0xFF757575),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ModernAppIcon extends StatelessWidget {
  final double size;

  const ModernAppIcon({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5), Color(0xFF64B5F6)],
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withValues(alpha: 0.4),
            spreadRadius: 3,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background pattern
          Positioned(
            top: size * 0.15,
            right: size * 0.15,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(size * 0.1),
              ),
            ),
          ),

          // Main chat icon
          Icon(Icons.chat_bubble, color: Colors.white, size: size * 0.5),

          // Notification dot
          Positioned(
            top: size * 0.1,
            right: size * 0.1,
            child: Container(
              width: size * 0.15,
              height: size * 0.15,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
