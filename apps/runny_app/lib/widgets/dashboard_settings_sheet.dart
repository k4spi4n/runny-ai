import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/dashboard_layout.dart';

/// Bảng tùy chỉnh các mục của trang Tổng quan: bật/tắt và kéo để sắp xếp.
/// Mở từ nút "Tùy chỉnh màn hình" trên thanh điều hướng khi đang ở dashboard.
class DashboardSettingsSheet extends StatelessWidget {
  final DashboardLayout layout;

  const DashboardSettingsSheet({super.key, required this.layout});

  static Future<void> show(BuildContext context, DashboardLayout layout) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DashboardSettingsSheet(layout: layout),
    );
  }

  String _sectionLabel(BuildContext context, String key) {
    switch (key) {
      case DashboardLayout.nutrition:
        return context.translate('nutrition_status');
      case DashboardLayout.performance:
        return context.translate('performance_overview');
      case DashboardLayout.aiInsight:
        return context.translate('ai_insight_title');
      default:
        return key;
    }
  }

  IconData _sectionIcon(String key) {
    switch (key) {
      case DashboardLayout.nutrition:
        return Icons.restaurant;
      case DashboardLayout.performance:
        return Icons.insights;
      case DashboardLayout.aiInsight:
        return Icons.auto_awesome;
      default:
        return Icons.dashboard_customize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: AnimatedBuilder(
          animation: layout,
          builder: (context, _) {
            final order = layout.order;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.dashboard_customize, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.translate('dashboard_settings_title'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context.translate('dashboard_settings_hint'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: order.length,
                  onReorderItem: layout.reorder,
                  itemBuilder: (context, index) {
                    final key = order[index];
                    final visible = layout.isVisible(key);
                    return Padding(
                      key: ValueKey(key),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                                child: Icon(
                                  Icons.drag_indicator,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Icon(
                              _sectionIcon(key),
                              size: 20,
                              color: visible
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _sectionLabel(context, key),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: visible
                                      ? colorScheme.onSurface
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch(
                              value: visible,
                              onChanged: (v) => layout.setVisible(key, v),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: layout.resetToDefault,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: Text(context.translate('reset_default')),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.translate('done')),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
