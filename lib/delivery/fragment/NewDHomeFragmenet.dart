import 'package:flutter/material.dart';

class DriverDashboardUI extends StatefulWidget {
  const DriverDashboardUI({super.key});

  @override
  State<DriverDashboardUI> createState() => _DriverDashboardUIState();
}

class _DriverDashboardUIState extends State<DriverDashboardUI> {
  int selectedTab = 0; // 0 = Today, 1 = In Progress, 2 = Remaining

  // 🔹 Data per tab
  final List<Map<String, String>> tabStats = [
    // Today tab
    {
      'today': '3',
      'progress': '2',
      'remaining': '5',
    },
    // In Progress tab
    {
      'today': '0',
      'progress': '4',
      'remaining': '1',
    },
    // Remaining tab
    {
      'today': '0',
      'progress': '1',
      'remaining': '6',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: _cardDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Hey Jessica 👋',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ahmedabad • Online',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    _IconCircle(icon: Icons.notifications_none),
                    const SizedBox(width: 8),
                    _IconCircle(icon: Icons.settings),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "Today's Work",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 12),

              // Work Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    // Tabs
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _TabText(
                            title: 'Today',
                            active: selectedTab == 0,
                            onTap: () => setState(() => selectedTab = 0),
                          ),
                          _TabText(
                            title: 'In Progress',
                            active: selectedTab == 1,
                            onTap: () => setState(() => selectedTab = 1),
                          ),
                          _TabText(
                            title: 'Remaining',
                            active: selectedTab == 2,
                            onTap: () => setState(() => selectedTab = 2),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stats (dynamic per tab)
                    _buildStats(
                      today: tabStats[selectedTab]['today']!,
                      progress: tabStats[selectedTab]['progress']!,
                      remaining: tabStats[selectedTab]['remaining']!,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 12),

              Row(
                children: const [
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.check_circle_outline,
                      iconColor: Colors.green,
                      title: '0',
                      subtitle: 'Completed',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.attach_money,
                      iconColor: Colors.blue,
                      title: 'KWD 0.00',
                      subtitle: "Today's Earnings",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Wallet Balance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'KWD 5,192.90',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Wallet Balance',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4FACFE), Color(0xFF00C6FB)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Withdraw',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4FACFE), Color(0xFF00C6FB)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(
                  child: Text(
                    'View all orders (7)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats({
    required String today,
    required String progress,
    required String remaining,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatBlock(value: today, label: 'Today'),
        _StatBlock(
          value: progress,
          label: 'In Progress',
          icon: Icons.local_shipping_outlined,
          color: Colors.blue,
        ),
        _StatBlock(
          value: remaining,
          label: 'Remaining',
          icon: Icons.assignment_outlined,
          color: Colors.orange,
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha:0.04),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

// ---------------- Helper Widgets ----------------

class _IconCircle extends StatelessWidget {
  final IconData icon;
  const _IconCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, size: 20),
    );
  }
}

class _TabText extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _TabText({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.blue : Colors.grey,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  const _StatBlock({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon != null) Icon(icon, size: 30, color: color),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color ?? Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
