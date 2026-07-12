import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/readiness_models.dart';
import '../services/readiness_service.dart';
import 'ui_components.dart';

class ReadinessCard extends StatelessWidget {
  final ReadinessSnapshot snapshot;
  final VoidCallback onCheckin;
  const ReadinessCard({
    super.key,
    required this.snapshot,
    required this.onCheckin,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color =
        snapshot.painFlag ||
            snapshot.status == 'low' ||
            snapshot.status == 'rest'
        ? Colors.redAccent
        : snapshot.status == 'caution'
        ? Colors.orangeAccent
        : Colors.green;
    final statusKey = 'readiness_${snapshot.status}';
    return glassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.translate('readiness'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${snapshot.score}/100',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.translate(statusKey),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Metric(
                label: context.translate('acute_load'),
                value: snapshot.acuteLoad.toStringAsFixed(0),
              ),
              _Metric(
                label: context.translate('chronic_load'),
                value: snapshot.chronicLoad.toStringAsFixed(0),
              ),
              _Metric(
                label: 'ACWR',
                value: snapshot.acwr?.toStringAsFixed(2) ?? '--',
              ),
            ],
          ),
          if (!snapshot.hasSufficientLoadData)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                context.translate('readiness_low_confidence'),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
          if (snapshot.painFlag)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                context.translate('readiness_pain_warning'),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onCheckin,
            icon: const Icon(Icons.nightlight_round_outlined, size: 18),
            label: Text(
              context.translate(
                snapshot.needsCheckin
                    ? 'readiness_checkin'
                    : 'readiness_update_checkin',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ],
  );
}

Future<bool?> showRecoveryCheckinSheet(
  BuildContext context, {
  RecoveryCheckin? initial,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RecoveryCheckinSheet(initial: initial),
  );
}

class _RecoveryCheckinSheet extends StatefulWidget {
  final RecoveryCheckin? initial;
  const _RecoveryCheckinSheet({this.initial});
  @override
  State<_RecoveryCheckinSheet> createState() => _RecoveryCheckinSheetState();
}

class _RecoveryCheckinSheetState extends State<_RecoveryCheckinSheet> {
  late double _sleepQuality;
  late double _soreness;
  late bool _pain;
  late TextEditingController _hours;
  late TextEditingController _notes;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    _sleepQuality = (v?.sleepQuality ?? 3).toDouble();
    _soreness = (v?.soreness ?? 0).toDouble();
    _pain = v?.painFlag ?? false;
    _hours = TextEditingController(text: v?.sleepHours?.toString() ?? '');
    _notes = TextEditingController(text: v?.notes ?? '');
  }

  @override
  void dispose() {
    _hours.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.translate('readiness_checkin'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(context.translate('sleep_quality')),
              Slider(
                value: _sleepQuality,
                min: 1,
                max: 5,
                divisions: 4,
                label: _sleepQuality.round().toString(),
                onChanged: (v) => setState(() => _sleepQuality = v),
              ),
              TextField(
                controller: _hours,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.translate('sleep_hours'),
                ),
              ),
              const SizedBox(height: 12),
              Text(context.translate('soreness')),
              Slider(
                value: _soreness,
                min: 0,
                max: 10,
                divisions: 10,
                label: _soreness.round().toString(),
                onChanged: (v) => setState(() => _soreness = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _pain,
                onChanged: (v) => setState(() => _pain = v),
                title: Text(context.translate('pain_flag')),
                subtitle: Text(context.translate('pain_flag_hint')),
              ),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.translate('notes'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await ReadinessService().saveCheckin(
                              RecoveryCheckin(
                                date: DateTime.now(),
                                sleepQuality: _sleepQuality.round(),
                                sleepHours: double.tryParse(_hours.text),
                                soreness: _soreness.round(),
                                painFlag: _pain,
                                notes: _notes.text,
                              ),
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop(true);
                          } catch (_) {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  child: Text(context.translate('save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
