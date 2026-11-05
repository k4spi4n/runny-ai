import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/recorded_run.dart';
import '../services/run_recording_service.dart';
import '../utils/activity_formatters.dart';
import '../widgets/run_route_map.dart';

class RecordRunPage extends StatefulWidget {
  const RecordRunPage({super.key});

  @override
  State<RecordRunPage> createState() => _RecordRunPageState();
}

class _RecordRunPageState extends State<RecordRunPage>
    with WidgetsBindingObserver {
  late final RunRecordingService _recorder;

  @override
  void initState() {
    super.initState();
    _recorder = context.read<RunRecordingService>();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepare();
    });
  }

  Future<void> _prepare() => _recorder.prepare(
    title: context.translate('run_notification_title'),
    text: context.translate('run_notification_text'),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_prepare());
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_recorder.checkpoint());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_recorder.releasePreviewLocation());
    super.dispose();
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('run_discard_title')),
        content: Text(context.translate('run_discard_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.translate('run_discard')),
          ),
        ],
      ),
    );
    if (confirmed == true && await _recorder.discard() && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final activity = await _recorder.save(
      context.translate('run_outdoor_name'),
    );
    if (activity != null && mounted) Navigator.pop(context, activity);
  }

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<RunRecordingService>();
    final run = recorder.draft;
    final finished = run?.phase == RunPhase.finished;
    final paused = run?.phase == RunPhase.paused;
    final message = paused ? 'run_paused' : recorder.locationMessage;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.translate(finished ? 'run_finish_preview' : 'run_record'),
        ),
      ),
      body: recorder.loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.42,
                      child: RunRouteMap(
                        segments: run?.segments ?? const [],
                        position: finished ? null : recorder.livePosition,
                        live: !finished,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _stat(
                          'distance',
                          '${((run?.distanceM ?? 0) / 1000).toStringAsFixed(2)} ${context.translate('km')}',
                        ),
                        _stat(
                          'run_active_duration',
                          formatDurationMinutes(
                            (run?.elapsedMs(recorder.now) ?? 0) / 60000,
                          ),
                        ),
                        _stat(
                          'avg_pace',
                          '${formatPace(run?.pace(recorder.now))} ${context.translate('min_km')}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (recorder.error != null) ...[
                      Text(
                        context.translate(recorder.error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (recorder.recoveryFailed)
                        TextButton(
                          onPressed: recorder.retryRecovery,
                          child: Text(context.translate('retry')),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (finished) ...[
                      Text(context.translate('run_draft_kept')),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: recorder.saving ? null : _save,
                        icon: recorder.saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(context.translate('save')),
                      ),
                      TextButton(
                        onPressed: recorder.saving ? null : _discard,
                        child: Text(context.translate('run_discard')),
                      ),
                    ] else ...[
                      Text(
                        context.translate(message),
                        key: const ValueKey('run_gps_status'),
                      ),
                      if (!recorder.hasFix)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: recorder.busy ? null : _prepare,
                              child: Text(context.translate('run_retry_gps')),
                            ),
                            TextButton(
                              onPressed: () =>
                                  recorder.location.openAppSettings(),
                              child: Text(
                                context.translate('run_app_settings'),
                              ),
                            ),
                            if (message == 'run_location_disabled')
                              TextButton(
                                onPressed: () =>
                                    recorder.location.openLocationSettings(),
                                child: Text(
                                  context.translate('run_location_settings'),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      if (run == null)
                        FilledButton(
                          onPressed: recorder.canStart ? recorder.start : null,
                          child: Text(context.translate('run_start')),
                        )
                      else ...[
                        FilledButton.icon(
                          onPressed: paused
                              ? () async {
                                  await recorder.resume();
                                  await _prepare();
                                }
                              : recorder.pause,
                          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                          label: Text(
                            context.translate(
                              paused ? 'run_resume' : 'run_pause',
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: recorder.finish,
                          child: Text(context.translate('run_finish')),
                        ),
                        Text(context.translate('run_background_hint')),
                      ],
                      if (recorder.recoveryFailed)
                        TextButton(
                          onPressed: _discard,
                          child: Text(context.translate('run_discard')),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _stat(String label, String value) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(context.translate(label)),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
