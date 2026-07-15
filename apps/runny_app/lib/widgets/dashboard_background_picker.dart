import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../theme/app_background.dart';
import 'ui_components.dart';

class DashboardBackgroundLayer extends StatelessWidget {
  final AppBackground background;
  final int pageIndex;
  final int pageCount;

  const DashboardBackgroundLayer({
    super.key,
    required this.background,
    this.pageIndex = 0,
    this.pageCount = 1,
  });

  /// Trải đều các màn hình trên toàn chiều rộng ảnh. `BoxFit.cover` tự tính
  /// lát cắt theo kích thước viewport hiện tại; trên màn hình dọc, các lát cắt
  /// sẽ overlap tự nhiên vì mỗi lát hẹp hơn ảnh gốc.
  static double alignmentXForPage(int pageIndex, int pageCount) {
    if (pageCount <= 1) return 0;
    final safeIndex = pageIndex.clamp(0, pageCount - 1);
    return -1 + (2 * safeIndex / (pageCount - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetPath = background.assetPath;
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final targetAlignment = Alignment(
      alignmentXForPage(pageIndex, pageCount),
      0,
    );

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
                TweenAnimationBuilder<Alignment>(
                  key: const ValueKey('dashboard-background-pan'),
                  tween: AlignmentTween(end: targetAlignment),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeInOutCubic,
                  builder: (context, alignment, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Image.asset(
                          assetPath,
                          key: const ValueKey('dashboard-background-image'),
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          fit: BoxFit.cover,
                          alignment: alignment,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        );
                      },
                    );
                  },
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

class DashboardBackgroundPicker extends StatefulWidget {
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
  State<DashboardBackgroundPicker> createState() =>
      _DashboardBackgroundPickerState();
}

class _DashboardBackgroundPickerState extends State<DashboardBackgroundPicker> {
  late int _currentIndex;

  static const _animationDuration = Duration(milliseconds: 320);

  @override
  void initState() {
    super.initState();
    _currentIndex = AppBackground.values.indexOf(widget.selected);
  }

  @override
  void didUpdateWidget(covariant DashboardBackgroundPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedIndex = AppBackground.values.indexOf(widget.selected);
    if (selectedIndex != _currentIndex) {
      _currentIndex = selectedIndex;
    }
  }

  int _relativeDistance(int index) {
    final count = AppBackground.values.length;
    var distance = (index - _currentIndex) % count;
    if (distance > count / 2) distance -= count;
    return distance;
  }

  void _selectIndex(int index) {
    final pageCount = AppBackground.values.length;
    final wrappedIndex = (index % pageCount + pageCount) % pageCount;
    if (wrappedIndex == _currentIndex) return;
    setState(() => _currentIndex = wrappedIndex);
    widget.onSelected(AppBackground.values[wrappedIndex]);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) return;
    _selectIndex(_currentIndex + (velocity < 0 ? 1 : -1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selectedBackground = AppBackground.values[_currentIndex];
    final selectedLabel =
        widget.labels[selectedBackground] ?? selectedBackground.name;

    return SizedBox(
      height: 286,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: _handleHorizontalDragEnd,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth * 0.54)
                          .clamp(146.0, 200.0)
                          .toDouble();
                      final indices =
                          List<int>.generate(
                            AppBackground.values.length,
                            (index) => index,
                          )..sort((a, b) {
                            final depthCompare = _relativeDistance(
                              b,
                            ).abs().compareTo(_relativeDistance(a).abs());
                            if (depthCompare != 0) return depthCompare;
                            return _relativeDistance(
                              a,
                            ).compareTo(_relativeDistance(b));
                          });

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final index in indices)
                            _buildBackgroundCard(
                              context,
                              index: index,
                              distance: _relativeDistance(index),
                              width: cardWidth,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Row(
              children: [
                _CarouselArrowButton(
                  key: const ValueKey('background-previous'),
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).previousPageTooltip,
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: () => _selectIndex(_currentIndex - 1),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          selectedLabel,
                          key: ValueKey(selectedBackground),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          AppBackground.values.length,
                          (index) => Semantics(
                            button: true,
                            selected: index == _currentIndex,
                            child: InkWell(
                              key: ValueKey('background-indicator-$index'),
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => _selectIndex(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: index == _currentIndex ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: index == _currentIndex
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _CarouselArrowButton(
                  key: const ValueKey('background-next'),
                  tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                  icon: Icons.arrow_forward_ios_rounded,
                  onPressed: () => _selectIndex(_currentIndex + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundCard(
    BuildContext context, {
    required int index,
    required int distance,
    required double width,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = AppBackground.values[index];
    final label = widget.labels[background] ?? background.name;
    final assetPath = background.assetPath;
    final depth = distance.abs();
    final isSelected = depth == 0;
    final isVisible = depth <= 2;
    final alignmentX = switch (distance) {
      <= -2 => -1.0,
      -1 => -0.62,
      0 => 0.0,
      1 => 0.62,
      _ => 1.0,
    };
    final scale = switch (depth) {
      0 => 1.0,
      1 => 0.86,
      _ => 0.73,
    };
    final opacity = switch (depth) {
      0 => 1.0,
      1 => 0.66,
      2 => 0.32,
      _ => 0.0,
    };

    return AnimatedAlign(
      key: ValueKey('background-position-${background.name}'),
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment(alignmentX, 0),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          duration: _animationDuration,
          curve: Curves.easeOutCubic,
          opacity: opacity,
          child: AnimatedScale(
            duration: _animationDuration,
            curve: Curves.easeOutBack,
            scale: scale,
            child: Semantics(
              label: label,
              button: true,
              selected: isSelected,
              child: SizedBox(
                width: width,
                height: 220,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('background-option-${background.name}'),
                    onTap: () => _selectIndex(index),
                    child: AnimatedContainer(
                      duration: _animationDuration,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.surface.withValues(alpha: 0.8),
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.3)
                                : colorScheme.shadow.withValues(alpha: 0.16),
                            blurRadius: isSelected ? 18 : 10,
                            spreadRadius: isSelected ? 1 : 0,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (assetPath == null)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: sportPlatformGradient(context),
                              ),
                              child: Icon(
                                Icons.hide_image_outlined,
                                color: colorScheme.onSurfaceVariant,
                                size: 36,
                              ),
                            )
                          else
                            Image.asset(
                              assetPath,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                            ),
                          if (!isSelected)
                            ColoredBox(
                              color: colorScheme.surface.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.08
                                    : 0.12,
                              ),
                            ),
                          if (isSelected)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                key: ValueKey(
                                  'background-selected-${background.name}',
                                ),
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.onPrimary.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarouselArrowButton extends StatelessWidget {
  const _CarouselArrowButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(38),
        maximumSize: const Size.square(38),
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.72,
        ),
        foregroundColor: colorScheme.onSurfaceVariant,
      ),
      icon: Icon(icon, size: 16),
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
  size: Size(430, 320),
  brightness: Brightness.light,
)
@Preview(
  name: 'Background picker - dark',
  group: 'Dashboard customization',
  size: Size(430, 320),
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
