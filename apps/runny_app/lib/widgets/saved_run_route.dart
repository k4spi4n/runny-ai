import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/recorded_run.dart';
import '../services/run_recording_service.dart';
import 'run_route_map.dart';

class SavedRunRoute extends StatefulWidget {
  const SavedRunRoute({
    super.key,
    required this.activityId,
    required this.userId,
  });
  final String activityId;
  final String userId;

  @override
  State<SavedRunRoute> createState() => _SavedRunRouteState();
}

class _SavedRunRouteState extends State<SavedRunRoute> {
  late Future<List<List<RunFix>>?> _route;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _route = context.read<RunRecordingService>().loadRoute(widget.activityId);
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<RunRecordingService>().currentUserId != widget.userId) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<List<RunFix>>?>(
      future: _route,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Column(
            children: [
              Text(context.translate('run_route_load_error')),
              TextButton(
                onPressed: () => setState(_load),
                child: Text(context.translate('retry')),
              ),
            ],
          );
        }
        return SizedBox(
          height: 320,
          child: RunRouteMap(segments: snapshot.data!),
        );
      },
    );
  }
}
