import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChatIcon extends StatelessWidget {
  final bool isActive;
  final double size;

  const ChatIcon({
    Key? key,
    this.isActive = false,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // SVG inline para ícone de chat customizado
    final String svgIcon = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <!-- Chat bubble com pulse -->
  <path d="M12 2C6.48 2 2 5.58 2 10c0 2.05.84 3.95 2.25 5.32C4.09 17.5 3 21 3 21s3.5-1.1 5.68-1.25C10.05 21.16 11.95 22 14 22c5.42 0 10-3.58 10-8s-4.58-10-10-10z"
    fill="${isActive ? '#6366F1' : '#9CA3AF'}"
    opacity="${isActive ? '1' : '0.7'}"/>

  <!-- Ponto indicador (unread) -->
  ${isActive ? '''
  <circle cx="19" cy="6" r="2.5" fill="#EF4444"/>
  <circle cx="19" cy="6" r="4" fill="none" stroke="#EF4444" stroke-width="0.5" opacity="0.4"/>
  ''' : ''}
</svg>
    ''';

    return SvgPicture.string(
      svgIcon,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        isActive ? const Color(0xFF6366F1) : Colors.grey,
        BlendMode.srcIn,
      ),
    );
  }
}

// Versão alternativa: ícone com animação de "novo"
class AnimatedChatIcon extends StatefulWidget {
  final bool hasNewMessages;
  final double size;

  const AnimatedChatIcon({
    Key? key,
    this.hasNewMessages = false,
    this.size = 24,
  }) : super(key: key);

  @override
  State<AnimatedChatIcon> createState() => _AnimatedChatIconState();
}

class _AnimatedChatIconState extends State<AnimatedChatIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    if (widget.hasNewMessages) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedChatIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasNewMessages && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.hasNewMessages && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ícone principal
        Icon(
          Icons.message_rounded,
          size: widget.size,
          color: Colors.grey,
        ),

        // Pulsação se houver mensagens novas
        if (widget.hasNewMessages)
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.3).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
            ),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.withOpacity(0.6),
                  width: 2,
                ),
              ),
            ),
          ),

        // Badge de mensagens novas
        if (widget.hasNewMessages)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// Versão premium: ícone com speech bubble estilizado
class PulsosChatIcon extends StatelessWidget {
  final bool isActive;
  final int unreadCount;
  final double size;

  const PulsosChatIcon({
    Key? key,
    this.isActive = false,
    this.unreadCount = 0,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Bubble principal com gradiente
        Container(
          width: size,
          height: size * 0.85,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6366F1)
                : Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(
            Icons.mail_outline,
            size: size * 0.6,
            color: isActive ? Colors.white : Colors.grey,
          ),
        ),

        // Cauda da bubble
        Positioned(
          bottom: -2,
          right: size * 0.15,
          child: Transform.rotate(
            angle: 0.785, // 45 graus
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF6366F1)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(size * 0.1),
              ),
            ),
          ),
        ),

        // Badge de unread
        if (unreadCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
