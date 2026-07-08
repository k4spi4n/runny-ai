import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/run_timer_controller.dart';
import 'ui_components.dart';

class RunTimerPanel extends StatefulWidget {
  const RunTimerPanel({super.key});

  @override
  State<RunTimerPanel> createState() => _RunTimerPanelState();
}

class _RunTimerPanelState extends State<RunTimerPanel> {
  late final RunTimerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RunTimerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isActive = _controller.status == RunTimerStatus.running;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: isActive ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.translate('run_timer'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  badgeLabel(context, _statusLabel(context)),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatElapsed(_controller.elapsed),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (_controller.status == RunTimerStatus.notStarted ||
                      _controller.status == RunTimerStatus.finished)
                    ElevatedButton.icon(
                      onPressed: _controller.start,
                      style: primaryActionButton(context),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(context.translate('timer_start')),
                    ),
                  if (_controller.status == RunTimerStatus.running)
                    OutlinedButton.icon(
                      onPressed: _controller.pause,
                      icon: const Icon(Icons.pause, size: 18),
                      label: Text(context.translate('timer_pause')),
                    ),
                  if (_controller.status == RunTimerStatus.paused)
                    ElevatedButton.icon(
                      onPressed: _controller.resume,
                      style: primaryActionButton(context),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(context.translate('timer_resume')),
                    ),
                  if (_controller.status == RunTimerStatus.running ||
                      _controller.status == RunTimerStatus.paused)
                    OutlinedButton.icon(
                      onPressed: _controller.finish,
                      icon: const Icon(Icons.stop, size: 18),
                      label: Text(context.translate('timer_finish')),
                    ),
                  if (_controller.status == RunTimerStatus.finished)
                    OutlinedButton.icon(
                      onPressed: _controller.reset,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: Text(context.translate('timer_reset')),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(BuildContext context) {
    switch (_controller.status) {
      case RunTimerStatus.notStarted:
        return context.translate('timer_not_started');
      case RunTimerStatus.running:
        return context.translate('timer_running');
      case RunTimerStatus.paused:
        return context.translate('timer_paused');
      case RunTimerStatus.finished:
        return context.translate('timer_finished');
    }
  }

  String _formatElapsed(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return [
      hours.toString().padLeft(2, '0'),
      minutes.toString().padLeft(2, '0'),
      seconds.toString().padLeft(2, '0'),
    ].join(':');
  }
}
