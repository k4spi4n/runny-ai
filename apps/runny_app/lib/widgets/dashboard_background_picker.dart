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
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = AppBackground.values.indexOf(widget.selected);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(covariant DashboardBackgroundPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedIndex = AppBackground.values.indexOf(widget.selected);
    if (selectedIndex != _currentIndex) {
      _currentIndex = selectedIndex;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(selectedIndex);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index.clamp(0, AppBackground.values.length - 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 184,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: AppBackground.values.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                widget.onSelected(AppBackground.values[index]);
              },
              itemBuilder: (context, index) {
                final background = AppBackground.values[index];
                final isSelected = index == _currentIndex;
                final label = widget.labels[background] ?? background.name;
                final assetPath = background.assetPath;

                return Semantics(
                  label: label,
                  button: true,
                  selected: isSelected,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey('background-option-${background.name}'),
                        onTap: () => widget.onSelected(background),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
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
                                            color: colorScheme.primary
                                                .withValues(alpha: 0.25),
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
                                          gradient: sportPlatformGradient(
                                            context,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.block_rounded,
                                          color: colorScheme.onSurfaceVariant,
                                          size: 30,
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
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          key: ValueKey(
                                            'background-selected-${background.name}',
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary,
                                            shape: BoxShape.circle,
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
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                key: const ValueKey('background-previous'),
                onPressed: _currentIndex == 0
                    ? null
                    : () => _goToPage(_currentIndex - 1),
                icon: const Icon(Icons.arrow_back_ios_new),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    AppBackground.values.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _currentIndex ? 18 : 7,
                      height: 7,
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
              IconButton(
                key: const ValueKey('background-next'),
                onPressed: _currentIndex == AppBackground.values.length - 1
                    ? null
                    : () => _goToPage(_currentIndex + 1),
                icon: const Icon(Icons.arrow_forward_ios),
              ),
            ],
          ),
        ],
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
  size: Size(760, 220),
  brightness: Brightness.light,
)
@Preview(
  name: 'Background picker - dark',
  group: 'Dashboard customization',
  size: Size(760, 220),
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
