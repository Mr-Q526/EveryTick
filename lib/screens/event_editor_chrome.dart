import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const eventEditorBg = Color(0xFFF7FBFF);
const eventEditorBgTop = Color(0xFFFAFDFF);
const eventEditorBgMid = Color(0xFFEFF7FF);
const eventEditorBgBottom = Color(0xFFF2FFF8);
const eventEditorInputFill = Color(0xFFF6FAFF);
const eventEditorInk = Color(0xFF1C1C1E);
const eventEditorMuted = Color(0xFF6E6E73);
const eventEditorLine = Color(0xFFD1D1D6);
const eventEditorRadius = 8.0;

class EventEditorBackground extends StatelessWidget {
  final Widget child;

  const EventEditorBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [eventEditorBgTop, eventEditorBgMid, eventEditorBgBottom],
          stops: [0, 0.54, 1],
        ),
      ),
      child: child,
    );
  }
}

class EventEditorGlassPanel extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color borderColor;
  final Color tint;
  final double? width;

  const EventEditorGlassPanel({
    super.key,
    required this.child,
    required this.accent,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderColor = eventEditorLine,
    this.tint = Colors.white,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(eventEditorRadius),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.09),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.78),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.76),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                accent.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.78),
              ],
              stops: const [0, 0.52, 1],
            ),
            borderRadius: BorderRadius.circular(eventEditorRadius),
            border: Border.all(color: borderColor.withValues(alpha: 0.72)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.82)),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class EventEditorHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String mark;
  final Color color;
  final VoidCallback onClose;

  const EventEditorHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.mark,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return EventEditorGlassPanel(
      accent: color,
      borderColor: color.withValues(alpha: 0.36),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(eventEditorRadius),
              border: Border.all(color: color.withValues(alpha: 0.16)),
            ),
            alignment: Alignment.center,
            child: Text(mark, style: const TextStyle(fontSize: 25)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: eventEditorInk,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: eventEditorMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EventEditorPressableScale(
            child: Material(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(eventEditorRadius),
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(eventEditorRadius),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(eventEditorRadius),
                    border: Border.all(color: eventEditorLine),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: eventEditorMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EventEditorPrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const EventEditorPrimaryButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: EventEditorPressableScale(
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(eventEditorRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(eventEditorRadius),
            child: Container(
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(eventEditorRadius),
                boxShadow: AppShadows.colored(color),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EventEditorPressableScale extends StatefulWidget {
  final Widget child;

  const EventEditorPressableScale({super.key, required this.child});

  @override
  State<EventEditorPressableScale> createState() =>
      _EventEditorPressableScaleState();
}

class _EventEditorPressableScaleState extends State<EventEditorPressableScale> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) {
      return;
    }
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
