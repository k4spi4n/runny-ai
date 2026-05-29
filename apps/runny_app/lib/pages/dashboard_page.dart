import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const Center(child: Text('Trang chủ - Tổng quan')),
    const Center(child: Text('Lịch sử chạy bộ')),
    const Center(child: Text('Lịch tập luyện')),
    const Center(child: Text('Trợ lý AI')),
    const Center(child: Text('Cài đặt & Hồ sơ')),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Runny AI Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
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
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _selectedIndex == 0
                ? const OverviewContent()
                : _pages[_selectedIndex],
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
                NavigationDestination(
                  icon: Icon(Icons.dashboard),
                  label: 'Tổng quan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'Lịch sử',
                ),
                NavigationDestination(
                  icon: Icon(Icons.psychology),
                  label: 'AI',
                ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chào mừng quay trở lại!',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 1200
                ? 4
                : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.5,
            children: const [
              StatCard(
                title: 'Tổng quãng đường',
                value: '42.5 km',
                icon: Icons.straighten,
                color: Colors.blue,
              ),
              StatCard(
                title: 'Số buổi chạy',
                value: '12',
                icon: Icons.directions_run,
                color: Colors.green,
              ),
              StatCard(
                title: 'Nhịp tim TB',
                value: '145 bpm',
                icon: Icons.favorite,
                color: Colors.red,
              ),
              StatCard(
                title: 'Pace trung bình',
                value: '5:45 /km',
                icon: Icons.speed,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Text(
                'Hoạt động gần đây',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('Xem tất cả')),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orangeAccent,
                    child: Icon(Icons.run_circle, color: Colors.white),
                  ),
                  title: Text('Chạy buổi sáng ${3 - index} ngày trước'),
                  subtitle: const Text('5.2 km • 30:15 • Pace 5:49'),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
