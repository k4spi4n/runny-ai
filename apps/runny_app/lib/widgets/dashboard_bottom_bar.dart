import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class DashboardBottomBar extends StatelessWidget {
  const DashboardBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.onRecord,
    this.hasRunDraft = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onRecord;
  final bool hasRunDraft;

  Future<void> _showMore(BuildContext context) async {
    final destination = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in [
                (1, Icons.calendar_month_outlined, 'training_plan'),
                if (onRecord != null) (2, Icons.chat_outlined, 'ai_coach'),
                (3, Icons.restaurant_outlined, 'nutrition'),
                (6, Icons.person_outline, 'profile'),
              ])
                ListTile(
                  leading: Icon(item.$2),
                  title: Text(context.translate(item.$3)),
                  selected: selectedIndex == item.$1,
                  onTap: () => Navigator.pop(context, item.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (destination != null) onSelected(destination);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recordLabel = context.translate(
      hasRunDraft ? 'run_continue' : 'run_record',
    );
    final destinations = [0, 4, if (onRecord == null) 2 else -1, 5];
    final currentIndex = destinations.indexOf(selectedIndex);

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: colors.surface,
      elevation: 12,
      selectedItemColor: colors.primary,
      unselectedItemColor: colors.onSurfaceVariant,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      currentIndex: currentIndex < 0 ? 4 : currentIndex,
      onTap: (index) {
        if (index == 4) {
          _showMore(context);
        } else if (index == 2 && onRecord != null) {
          onRecord!();
        } else {
          onSelected(destinations[index]);
        }
      },
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home),
          label: context.translate('nav_home'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.history),
          label: context.translate('history'),
        ),
        if (onRecord != null)
          BottomNavigationBarItem(
            tooltip: recordLabel,
            icon: Container(
              key: const ValueKey('nav-record-run'),
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFB91C1C),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasRunDraft
                    ? Icons.play_arrow_rounded
                    : Icons.fiber_manual_record,
                color: Colors.white,
                size: 30,
                semanticLabel: recordLabel,
              ),
            ),
            label: context.translate(
              hasRunDraft ? 'nav_return_run' : 'nav_record',
            ),
          )
        else
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_outlined),
            label: context.translate('ai_coach'),
          ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.groups_outlined),
          label: context.translate('community'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.menu),
          label: context.translate('nav_more'),
        ),
      ],
    );
  }
}
