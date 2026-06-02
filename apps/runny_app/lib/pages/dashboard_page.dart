import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'training_plan_page.dart';
import 'ai_coach_page.dart';
import 'import_activity_page.dart';
import '../widgets/ui_components.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const OverviewContent(),
      const Center(child: Text('Lịch sử chạy bộ', style: TextStyle(color: Colors.white))),
      const TrainingPlanPage(),
      const AICoachPage(),
      const Center(child: Text('Cài đặt & Hồ sơ', style: TextStyle(color: Colors.white))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Runny AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Nhập hoạt động',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImportActivityPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang đăng xuất...'), duration: Duration(seconds: 1)),
                );
              }
              try {
                await Supabase.instance.client.auth.signOut();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi đăng xuất: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const SizedBox.expand(child: DecoratedBox(decoration: BoxDecoration(gradient: sportPlatformGradient))),
          Positioned(
            top: 40,
            right: -120,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  NavigationRail(
                    extended: width > 1100,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Tổng quan'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history),
                        label: Text('Lịch sử'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: Text('Lịch tập'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.psychology_outlined),
                        selectedIcon: Icon(Icons.psychology),
                        label: Text('AI Coach'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('Hồ sơ'),
                      ),
                    ],
                  ),
                if (isDesktop) const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: _pages[_selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard), label: 'Tổng quan'),
                NavigationDestination(icon: Icon(Icons.history), label: 'Lịch sử'),
                NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Lịch tập'),
                NavigationDestination(icon: Icon(Icons.psychology), label: 'AI'),
                NavigationDestination(icon: Icon(Icons.person), label: 'Hồ sơ'),
              ],
            )
          : null,
    );
  }
}

class OverviewContent extends StatelessWidget {
  const OverviewContent({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200 ? 4 : (width > 800 ? 2 : 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          glassCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chào mừng trở lại, nhà vô địch.',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Trung tâm điều khiển thể thao của bạn đã sẵn sàng. Xem lại đà tập luyện mới nhất và giữ vững phong độ trước cuộc đua tiếp theo.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        badgeLabel('PRO HUD'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: accentPulseGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Điểm Kỹ thuật', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                              const SizedBox(height: 6),
                              Text('92', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _OverviewBadge(text: 'Tập trung Tốc độ'),
                    _OverviewBadge(text: 'Ưu tiên Phục hồi'),
                    _OverviewBadge(text: 'Hiệu suất Đỉnh cao'),
                    _OverviewBadge(text: 'Sẵn sàng Thi đấu'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Chỉ số Hiệu suất',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: const [
              PerformanceStatCard(
                title: 'Tổng quãng đường',
                value: '42.5 km',
                icon: Icons.straighten,
                gradient: accentPulseGradient,
              ),
              PerformanceStatCard(
                title: 'Số buổi',
                value: '12',
                icon: Icons.directions_run,
                gradient: secondaryPulseGradient,
              ),
              PerformanceStatCard(
                title: 'Nhịp tim TB',
                value: '145 bpm',
                icon: Icons.favorite,
                gradient: accentPulseGradient,
              ),
              PerformanceStatCard(
                title: 'Pace trung bình',
                value: '5:45 /km',
                icon: Icons.speed,
                gradient: secondaryPulseGradient,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Hoạt động mới nhất',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: glassCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    leading: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: index.isEven ? accentPulseGradient : secondaryPulseGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.run_circle, color: Colors.white, size: 28),
                    ),
                    title: Text('Chạy buổi sáng ${3 - index} ngày trước', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text('5.2 km • 30:15 • Pace 5:49', style: const TextStyle(color: Colors.white70)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Hành động nhanh',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionChip(text: 'Nhập hoạt động', icon: Icons.cloud_upload, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportActivityPage()));
                }),
                _ActionChip(text: 'Xem lịch tập', icon: Icons.calendar_month, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainingPlanPage()));
                }),
                _ActionChip(text: 'Hỏi AI Coach', icon: Icons.psychology, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AICoachPage()));
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class PerformanceStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;

  const PerformanceStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return glassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 10)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 10),
                Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewBadge extends StatelessWidget {
  final String text;

  const _OverviewBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({required this.text, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4A82FF), Color(0xFF3AB8FF)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
