import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/dashboard_layout.dart';
import '../theme/app_background.dart';
import '../theme/theme_provider.dart';
import 'dashboard_background_picker.dart';

/// Bảng tùy chỉnh các mục của trang Tổng quan: bật/tắt và kéo để sắp xếp.
/// Mở từ nút "Tùy chỉnh màn hình" trên thanh điều hướng khi đang ở dashboard.
class DashboardSettingsSheet extends StatelessWidget {
  final DashboardLayout layout;
  final bool showSections;

  const DashboardSettingsSheet({
    super.key,
    required this.layout,
    this.showSections = true,
  });

  static Future<void> show(
    BuildContext context,
    DashboardLayout layout, {
    bool showSections = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          DashboardSettingsSheet(layout: layout, showSections: showSections),
    );
  }

  String _sectionLabel(BuildContext context, String key) {
    switch (key) {
      case DashboardLayout.readiness:
        return context.translate('readiness');
      case DashboardLayout.nutrition:
        return context.translate('nutrition_status');
      case DashboardLayout.performance:
        return context.translate('performance_overview');
      case DashboardLayout.aiInsight:
        return context.translate('ai_insight_title');
      case DashboardLayout.todaySchedule:
        return context.translate('today_schedule');
      default:
        return key;
    }
  }

  IconData _sectionIcon(String key) {
    switch (key) {
      case DashboardLayout.readiness:
        return Icons.favorite_outline;
      case DashboardLayout.nutrition:
        return Icons.restaurant;
      case DashboardLayout.performance:
        return Icons.insights;
      case DashboardLayout.aiInsight:
        return Icons.auto_awesome;
      case DashboardLayout.todaySchedule:
        return Icons.event_available;
      default:
        return Icons.dashboard_customize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final labels = {
      for (final background in AppBackground.values)
        background: context.translate(background.labelKey),
    };

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
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
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          showSections
                              ? context.translate('dashboard_settings_title')
                              : context.translate('screen_settings'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.translate('background_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.translate('background_hint'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DashboardBackgroundPicker(
                    selected: themeProvider.background,
                    labels: labels,
                    onSelected: themeProvider.setBackground,
                  ),
                  if (showSections) ...[
                    const SizedBox(height: 12),
                    Divider(color: colorScheme.outlineVariant),
                    const SizedBox(height: 10),
                    Text(
                      context.translate('dashboard_sections_title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.translate('dashboard_settings_hint'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      4,
                                      0,
                                    ),
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
                                      : colorScheme.onSurfaceVariant.withValues(
                                          alpha: 0.5,
                                        ),
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
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          themeProvider.setBackground(AppBackground.none);
                          if (showSections) layout.resetToDefault();
                        },
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
      ),
    );
  }
}
