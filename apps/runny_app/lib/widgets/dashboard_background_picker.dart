import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../theme/app_background.dart';
import 'ui_components.dart';

class DashboardBackgroundLayer extends StatelessWidget {
  final AppBackground background;

  const DashboardBackgroundLayer({super.key, required this.background});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetPath = background.assetPath;
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;

    return SizedBox.expand(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: SizedBox.expand(
          key: ValueKey(background),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: sportPlatformGradient(context),
                ),
              ),
              if (assetPath != null)
                Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              if (assetPath != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        surface.withValues(alpha: isDark ? 0.74 : 0.76),
                        surface.withValues(alpha: isDark ? 0.52 : 0.58),
                        surface.withValues(alpha: isDark ? 0.72 : 0.78),
                      ],
                      stops: const [0, 0.52, 1],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardBackgroundPicker extends StatelessWidget {
  final AppBackground selected;
  final Map<AppBackground, String> labels;
  final ValueChanged<AppBackground> onSelected;

  const DashboardBackgroundPicker({
    super.key,
    required this.selected,
    required this.labels,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: AppBackground.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final background = AppBackground.values[index];
          final isSelected = selected == background;
          final label = labels[background] ?? background.name;
          final assetPath = background.assetPath;

          return Semantics(
            label: label,
            button: true,
            selected: isSelected,
            child: SizedBox(
              width: 124,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('background-option-${background.name}'),
                  onTap: () => onSelected(background),
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 78,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.7,
                                  ),
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (assetPath == null)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: sportPlatformGradient(context),
                                ),
                                child: Icon(
                                  Icons.block_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 26,
                                ),
                              )
                            else
                              Image.asset(
                                assetPath,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                              ),
                            if (isSelected)
                              ColoredBox(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            if (isSelected)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  key: ValueKey(
                                    'background-selected-${background.name}',
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

const _previewLabels = {
  AppBackground.none: 'Default',
  AppBackground.goldenStart: 'Golden start',
  AppBackground.flowingMiles: 'Flowing miles',
  AppBackground.electricPace: 'Electric pace',
  AppBackground.forestCalm: 'Forest calm',
  AppBackground.cityPulse: 'City pulse',
};

void previewBackgroundSelection(AppBackground _) {}

@Preview(
  name: 'Background picker - light',
  group: 'Dashboard customization',
  size: Size(760, 150),
  brightness: Brightness.light,
)
@Preview(
  name: 'Background picker - dark',
  group: 'Dashboard customization',
  size: Size(760, 150),
  brightness: Brightness.dark,
)
Widget dashboardBackgroundPickerPreview() {
  return Material(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: DashboardBackgroundPicker(
        selected: AppBackground.flowingMiles,
        labels: _previewLabels,
        onSelected: previewBackgroundSelection,
      ),
    ),
  );
}
