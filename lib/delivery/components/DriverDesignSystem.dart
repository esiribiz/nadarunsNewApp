import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../main/utils/Constants.dart';

/// Modern Premium Logistics Design System
/// Inspired by Uber Driver, Wolt Courier, Bolt Driver, and DoorDash
/// 
/// Design Principles:
/// - Map-first interface with floating bottom sheets
/// - Clean, minimal, premium aesthetic
/// - One-hand usability for drivers
/// - High contrast while driving
/// - Scandinavian modern UI

class DriverPalette {
  // Core Brand Colors - Electric Blue Theme
  static const Color primary = Color(0xFF0066FF);        // Electric Blue - Primary actions
  static const Color primaryDark = Color(0xFF0052CC);    // Darker blue for pressed states
  static const Color primaryLight = Color(0xFFE6F0FF);   // Light blue for backgrounds
  
  // Surface Colors
  static const Color surface = Color(0xFF0A0E1A);        // Deep black-blue background
  static const Color surfaceAlt = Color(0xFF151A28);     // Slightly lighter surface
  static const Color surfaceCard = Color(0xFFFFFFFF);    // White cards
  static const Color surfaceFloating = Color(0xFFFFFFFF); // Floating sheets
  
  // Text Colors
  static const Color textPrimary = Color(0xFF0A0E1A);    // Nearly black for light backgrounds
  static const Color textPrimaryInverse = Color(0xFFFFFFFF); // White for dark backgrounds
  static const Color textSecondary = Color(0xFF6B7280);  // Gray for secondary text
  static const Color textTertiary = Color(0xFF9CA3AF);   // Light gray for hints
  
  // Status Colors
  static const Color success = Color(0xFF10B981);        // Green for completed/delivered
  static const Color warning = Color(0xFFF59E0B);        // Amber for pending/waiting
  static const Color error = Color(0xFFEF4444);          // Red for cancelled/errors
  static const Color info = Color(0xFF3B82F6);           // Blue for info states
  
  // Navigation & Routes
  static const Color routeLine = Color(0xFF0066FF);      // Bright blue navigation routes
  static const Color routeLineActive = Color(0xFF00D4AA); // Teal for active route
  
  // Map & Location
  static const Color mapPinOrigin = Color(0xFF0066FF);   // Blue pickup pin
  static const Color mapPinDestination = Color(0xFF10B981); // Green dropoff pin
  static const Color mapDriverLocation = Color(0xFF000000); // Black driver dot
  
  // Borders & Dividers
  static const Color borderLight = Color(0xFFE5E7EB);    // Light borders
  static const Color borderMedium = Color(0xFFD1D5DB);   // Medium borders
  static const Color cardBorder = Color(0xFFE5E7EB);     // Card borders
  static const Color divider = Color(0xFFF3F4F6);        // Soft dividers
  
  // Backgrounds
  static const Color softBackground = Color(0xFFF8FAFC); // Soft light background
  
  // Shadows
  static const Color shadowLight = Color(0x0A000000);    // 4% black
  static const Color shadowMedium = Color(0x14000000);   // 8% black
  static const Color shadowHeavy = Color(0x1F000000);    // 12% black
  
  // Special Effects
  static const Color pulse = Color(0x400066FF);          // Pulsing animation
  static const Color overlay = Color(0x80000000);        // Modal overlays
  
  // Earnings
  static const Color earningsBackground = Color(0xFFF0FDF4); // Light green bg
  static const Color earningsText = Color(0xFF059669);   // Dark green text
  
  // Online/Offline
  static const Color online = Color(0xFF10B981);         // Green online indicator
  static const Color offline = Color(0xFF9CA3AF);        // Gray offline indicator
}

/// Status color mapping for order states
Color driverStatusColor(String status) {
  switch (status) {
    case ORDER_PENDING:
      return DriverPalette.warning;
    case ORDER_ASSIGNED:
      return DriverPalette.info;
    case ORDER_ACCEPTED:
      return DriverPalette.primary;
    case ORDER_ARRIVED:
      return const Color(0xFF0EA5E9);
    case ORDER_PICKED_UP:
      return DriverPalette.routeLineActive;
    case ORDER_DEPARTED:
      return const Color(0xFF6366F1);
    case ORDER_DELIVERED:
      return DriverPalette.success;
    case ORDER_CANCELLED:
      return DriverPalette.error;
    default:
      return DriverPalette.textSecondary;
  }
}

/// Get status label for order
String getStatusLabel(String status) {
  switch (status) {
    case ORDER_PENDING:
      return 'Pending';
    case ORDER_ASSIGNED:
      return 'Assigned';
    case ORDER_ACCEPTED:
      return 'Accepted';
    case ORDER_ARRIVED:
      return 'Arrived';
    case ORDER_PICKED_UP:
      return 'Picked Up';
    case ORDER_DEPARTED:
      return 'In Transit';
    case ORDER_DELIVERED:
      return 'Delivered';
    case ORDER_CANCELLED:
      return 'Cancelled';
    default:
      return status;
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
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: DriverPalette.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: DriverPalette.borderLight),
            boxShadow: [
              BoxShadow(
                color: DriverPalette.shadowMedium,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
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
    // Background - soft light gray
    final Paint bgPaint = Paint()..color = DriverPalette.divider;
    
    // Street lines - subtle gray
    final Paint streetPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Route line - electric blue with smooth stroke
    final Paint routePaint = Paint()
      ..color = routeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Draw background
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Draw horizontal streets
    for (double y = 16; y < size.height; y += 28) {
      final Path street = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * 0.35, y + 6, size.width, y - 3);
      canvas.drawPath(street, streetPaint);
    }

    // Draw vertical streets
    for (double x = 28; x < size.width; x += 48) {
      final Path street = Path()
        ..moveTo(x, 0)
        ..quadraticBezierTo(x - 8, size.height * 0.4, x + 6, size.height);
      canvas.drawPath(street, streetPaint);
    }

    // Draw main route path - smooth bezier curve
    final Path route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height * 0.52,
        size.width * 0.50,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.62,
        size.width * 0.82,
        size.height * 0.28,
      );
    canvas.drawPath(route, routePaint);

    // Route waypoints
    final Paint nodePaint = Paint()..color = routeColor;
    canvas.drawCircle(
      Offset(size.width * 0.40, size.height * 0.58),
      3.5,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.60, size.height * 0.55),
      3.5,
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
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverPalette.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: DriverPalette.borderLight,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: DriverPalette.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Modern status chip with subtle background and bold text
class DriverStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool showBackground;

  const DriverStatusChip({
    super.key, 
    required this.label, 
    required this.color,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: showBackground ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: showBackground ? null : Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Large, touch-friendly primary action button
/// Designed for one-hand operation while driving
class DriverPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? leading;
  final IconData? trailing;
  final bool isLoading;
  final bool enabled;
  final Color? backgroundColor;
  final double height;

  const DriverPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.enabled = true,
    this.backgroundColor,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? DriverPalette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: DriverPalette.textTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700, 
            fontSize: 16,
            letterSpacing: 0.3,
          ),
        ),
        onPressed: (isLoading || !enabled) ? null : onTap,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    Icon(leading, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailing, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Secondary outline button for less prominent actions
class DriverSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? leading;
  final bool isLoading;
  final Color? borderColor;
  final Color? textColor;

  const DriverSecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
    this.isLoading = false,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = borderColor ?? DriverPalette.primary;
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? color,
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700, 
            fontSize: 15,
          ),
        ),
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    Icon(leading, size: 19, color: color),
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
        ? DriverPalette.online
        : DriverPalette.offline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOnline 
            ? DriverPalette.online.withValues(alpha: 0.15)
            : DriverPalette.textTertiary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isOnline 
              ? DriverPalette.online.withValues(alpha: 0.3)
              : DriverPalette.textTertiary.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: stateColor,
              shape: BoxShape.circle,
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: DriverPalette.online.withValues(alpha: 0.5),
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
            style: TextStyle(
              color: stateColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: isOnline,
            onChanged: onChanged,
            activeThumbColor: DriverPalette.online,
            activeTrackColor: DriverPalette.online.withValues(alpha: 0.35),
            inactiveThumbColor: DriverPalette.textTertiary,
            inactiveTrackColor: DriverPalette.textTertiary.withValues(alpha: 0.3),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class DriverStepProgress extends StatefulWidget {
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
  State<DriverStepProgress> createState() => _DriverStepProgressState();
}

class _DriverStepProgressState extends State<DriverStepProgress>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _connectorAnimation;
  int _previousIndex = -1;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex - 1;
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _connectorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController.forward();
  }

  @override
  void didUpdateWidget(DriverStepProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _progressController.reset();
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) return const SizedBox();
    final int safeIndex = widget.currentIndex.clamp(0, widget.labels.length - 1).toInt();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: List.generate(widget.labels.length, (index) {
            final bool isCompleted = safeIndex >= index;
            final bool isCurrent = safeIndex == index;
            final Color stepColor = widget.statusColors != null &&
                    index < widget.statusColors!.length
                ? widget.statusColors![index]
                : DriverPalette.primary;
            final IconData? stepIcon = widget.icons != null &&
                    index < widget.icons!.length
                ? widget.icons![index]
                : null;

            return Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? stepColor.withValues(alpha: isCurrent ? 0.22 : 0.15)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted ? stepColor : const Color(0xFFCBD5E1),
                          width: isCurrent ? 3 : 2,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: stepColor.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(scale: animation, child: child);
                          },
                          child: isCompleted && !isCurrent
                              ? Icon(
                                  Icons.check,
                                  key: ValueKey('check_$index'),
                                  size: 22,
                                  color: stepColor,
                                )
                              : stepIcon != null
                                  ? Icon(
                                      stepIcon,
                                      key: ValueKey('icon_$index'),
                                      size: 20,
                                      color: isCompleted ? stepColor : const Color(0xFF94A3B8),
                                    )
                                  : Text(
                                      '${index + 1}',
                                      key: ValueKey('num_$index'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isCompleted
                                            ? stepColor
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 76,
                      child: Text(
                        widget.labels[index],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCompleted ? stepColor : const Color(0xFF64748B),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (index != widget.labels.length - 1)
                  Container(
                    width: 32,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 32),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          width: 32,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _connectorAnimation,
                          builder: (context, child) {
                            final double progress = index < safeIndex
                                ? 1.0
                                : (index == safeIndex - 1 && _previousIndex < safeIndex)
                                    ? _connectorAnimation.value
                                    : 0.0;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: Container(
                                width: 32 * progress,
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      widget.statusColors != null &&
                                              index + 1 < widget.statusColors!.length
                                          ? widget.statusColors![index + 1]
                                          : DriverPalette.primary,
                                      widget.statusColors != null &&
                                              index + 1 < widget.statusColors!.length
                                          ? widget.statusColors![index + 1].withValues(alpha: 0.7)
                                          : DriverPalette.primary.withValues(alpha: 0.7),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ),
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
        ? DriverPalette.mapPinDestination
        : DriverPalette.mapPinOrigin;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: DriverPalette.textTertiary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: DriverPalette.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (onCall != null)
              InkWell(
                onTap: onCall,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.call_outlined,
                    size: 20,
                    color: DriverPalette.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Metric display pill for showing delivery stats
class DriverMetricPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;

  const DriverMetricPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? DriverPalette.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DriverPalette.borderLight,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 16, 
            color: iconColor ?? DriverPalette.primary,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DriverPalette.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: DriverPalette.textSecondary,
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

/// Earnings summary card for displaying driver income
class DriverEarningsCard extends StatelessWidget {
  final String totalEarnings;
  final String tripsCompleted;
  final String onlineHours;
  final VoidCallback? onViewDetails;

  const DriverEarningsCard({
    super.key,
    required this.totalEarnings,
    required this.tripsCompleted,
    required this.onlineHours,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DriverPalette.primary,
            DriverPalette.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: DriverPalette.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Earnings',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onViewDetails != null)
                InkWell(
                  onTap: onViewDetails,
                  child: Row(
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            totalEarnings,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatItem(
                label: 'Trips',
                value: tripsCompleted,
                icon: Icons.shopping_bag_outlined,
              ),
              const SizedBox(width: 24),
              _StatItem(
                label: 'Hours',
                value: onlineHours,
                icon: Icons.access_time,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Customer info card with rating and details
class DriverCustomerCard extends StatelessWidget {
  final String customerName;
  final double rating;
  final int totalTrips;
  final String? avatarUrl;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  const DriverCustomerCard({
    super.key,
    required this.customerName,
    required this.rating,
    required this.totalTrips,
    this.avatarUrl,
    this.onCall,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverPalette.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriverPalette.borderLight),
        boxShadow: [
          BoxShadow(
            color: DriverPalette.shadowMedium,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: DriverPalette.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: DriverPalette.borderLight,
                width: 2,
              ),
            ),
            child: avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        size: 28,
                        color: DriverPalette.primary,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 28,
                    color: DriverPalette.primary,
                  ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: DriverPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      size: 16,
                      color: DriverPalette.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$rating',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DriverPalette.textPrimary,
                      ),
                    ),
                    Text(
                      ' • $totalTrips trips',
                      style: TextStyle(
                        fontSize: 13,
                        color: DriverPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onMessage != null)
                InkWell(
                  onTap: onMessage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: DriverPalette.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.message_outlined,
                      size: 22,
                      color: DriverPalette.primary,
                    ),
                  ),
                ),
              if (onMessage != null && onCall != null) const SizedBox(width: 8),
              if (onCall != null)
                InkWell(
                  onTap: onCall,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: DriverPalette.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.call,
                      size: 22,
                      color: DriverPalette.success,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
