import 'package:flutter/material.dart';
import '../../main/utils/Constants.dart';

class DriverPalette {
  static const Color surface = Color(0xFF07090F);
  static const Color surfaceAlt = Color(0xFF131725);
  static const Color primary = Color(0xFF573391);
  static const Color primaryDark = Color(0xFF462A77);
  static const Color accent = Color(0xFF22C55E);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFC5CBD9);
  static const Color cardBorder = Color(0xFFE4E8F0);
  static const Color cardBackground = Colors.white;
  static const Color softBackground = Color(0xFFF7F9FC);
}

Color driverStatusColor(String status) {
  switch (status) {
    case ORDER_PENDING:
      return const Color(0xFFF59E0B);
    case ORDER_ASSIGNED:
      return const Color(0xFF8B5CF6);
    case ORDER_ACCEPTED:
      return const Color(0xFF2563EB);
    case ORDER_ARRIVED:
      return const Color(0xFF0EA5E9);
    case ORDER_PICKED_UP:
      return const Color(0xFF06B6D4);
    case ORDER_DEPARTED:
      return const Color(0xFF6366F1);
    case ORDER_DELIVERED:
      return const Color(0xFF10B981);
    case ORDER_CANCELLED:
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF64748B);
  }
}

class DriverStageShell extends StatelessWidget {
  final Widget header;
  final Widget mapPreview;
  final Widget details;
  final VoidCallback? onTap;

  const DriverStageShell({
    super.key,
    required this.header,
    required this.mapPreview,
    required this.details,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: DriverPalette.cardBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: DriverPalette.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: DriverPalette.primary.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, mapPreview, details],
            ),
          ),
        ),
      ),
    );
  }
}

class DriverRoutePreview extends StatelessWidget {
  final Color routeColor;
  final bool showDropoffPulse;

  const DriverRoutePreview({
    super.key,
    required this.routeColor,
    this.showDropoffPulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DriverMapPreviewPainter(routeColor: routeColor),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 22,
            child: _RouteMarker(
              icon: Icons.radio_button_checked,
              color: DriverPalette.primary,
            ),
          ),
          Positioned(
            right: 24,
            top: 22,
            child: _RouteMarker(
              icon: Icons.place,
              color: DriverPalette.surface,
              pulse: showDropoffPulse,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool pulse;

  const _RouteMarker({
    required this.icon,
    required this.color,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (pulse)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
          ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 13, color: color),
        ),
      ],
    );
  }
}

class _DriverMapPreviewPainter extends CustomPainter {
  final Color routeColor;

  _DriverMapPreviewPainter({required this.routeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bgPaint = Paint()..color = DriverPalette.softBackground;
    final Paint streetPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final Paint routePaint = Paint()
      ..color = routeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(Offset.zero & size, bgPaint);

    for (double y = 12; y < size.height; y += 24) {
      final Path street = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * 0.35, y + 8, size.width, y - 2);
      canvas.drawPath(street, streetPaint);
    }

    for (double x = 24; x < size.width; x += 44) {
      final Path street = Path()
        ..moveTo(x, 0)
        ..quadraticBezierTo(x - 10, size.height * 0.4, x + 8, size.height);
      canvas.drawPath(street, streetPaint);
    }

    final Path route = Path()
      ..moveTo(size.width * 0.2, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.48,
        size.width * 0.52,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.6,
        size.width * 0.78,
        size.height * 0.32,
      );
    canvas.drawPath(route, routePaint);

    final Paint nodePaint = Paint()..color = routeColor;
    canvas.drawCircle(
      Offset(size.width * 0.42, size.height * 0.56),
      3,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.58, size.height * 0.57),
      3,
      nodePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DriverMapPreviewPainter oldDelegate) {
    return oldDelegate.routeColor != routeColor;
  }
}

class DriverCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const DriverCard({super.key, required this.child, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 14),
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DriverPalette.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: DriverPalette.cardBorder.withValues(alpha: 0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class DriverStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const DriverStatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class DriverPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? leading;
  final bool isLoading;

  const DriverPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: DriverPalette.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    Icon(leading, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class DriverOnlineToggle extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onChanged;

  const DriverOnlineToggle({
    super.key,
    required this.isOnline,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color stateColor = isOnline
        ? DriverPalette.accent
        : const Color(0xFF94A3B8);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: stateColor,
              shape: BoxShape.circle,
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: DriverPalette.accent.withValues(alpha: 0.55),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Switch.adaptive(
            value: isOnline,
            onChanged: onChanged,
            activeThumbColor: DriverPalette.accent,
            activeTrackColor: DriverPalette.accent.withValues(alpha: 0.35),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class DriverStepProgress extends StatelessWidget {
  final int currentIndex;
  final List<String> labels;
  final List<IconData>? icons;
  final List<Color>? statusColors;

  const DriverStepProgress({
    super.key,
    required this.currentIndex,
    required this.labels,
    this.icons,
    this.statusColors,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox();
    final int safeIndex = currentIndex.clamp(0, labels.length - 1).toInt();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final bool isCompleted = safeIndex >= index;
          final bool isCurrent = safeIndex == index;
          final Color stepColor = statusColors != null && index < statusColors!.length
              ? statusColors![index]
              : DriverPalette.primary;
          final IconData? stepIcon = icons != null && index < icons!.length
              ? icons![index]
              : null;
          
          return Row(
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? stepColor.withValues(alpha: isCurrent ? 0.22 : 0.15)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? stepColor : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                    ),
                    child: stepIcon != null
                        ? Icon(stepIcon, size: 18, color: isCompleted ? stepColor : const Color(0xFF94A3B8))
                        : Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isCompleted ? stepColor : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCompleted ? stepColor : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              if (index != labels.length - 1)
                Container(
                  width: 24,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 28),
                  color: isCompleted && index < safeIndex
                      ? (statusColors != null && index + 1 < statusColors!.length
                          ? statusColors![index + 1]
                          : DriverPalette.primary)
                      : const Color(0xFFCBD5E1),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class DriverAddressRow extends StatelessWidget {
  final String label;
  final String address;
  final bool isPickup;
  final VoidCallback? onTap;
  final VoidCallback? onCall;

  const DriverAddressRow({
    super.key,
    required this.label,
    required this.address,
    this.isPickup = true,
    this.onTap,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor = isPickup
        ? const Color(0xFF22C55E)
        : const Color(0xFF3B82F6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onCall != null)
              InkWell(
                onTap: onCall,
                child: const Padding(
                  padding: EdgeInsets.only(top: 4, left: 8),
                  child: Icon(
                    Icons.call_outlined,
                    size: 18,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DriverMetricPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const DriverMetricPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: DriverPalette.softBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DriverPalette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
