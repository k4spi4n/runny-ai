import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_models.dart';
import '../models/shoe_models.dart';
import '../widgets/ui_components.dart';
import '../widgets/activity_charts.dart';
import '../services/weather_service.dart';
import '../services/readiness_service.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'ai_coach_page.dart';

class ActivityDetailsPage extends StatefulWidget {
  final Activity activity;

  const ActivityDetailsPage({super.key, required this.activity});

  @override
  State<ActivityDetailsPage> createState() => _ActivityDetailsPageState();
}

class _ActivityDetailsPageState extends State<ActivityDetailsPage> {
  late Activity _activity;
  bool _isSaving = false;
  bool _hasChanged = false;
  double? _activeTime;
  List<Shoe> _shoes = [];
  Shoe? _currentShoe;
  int? _rpe;
  bool _isSavingRecovery = false;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _fetchShoeInfo();
    _loadRecoveryFeedback();
  }

  Future<void> _loadRecoveryFeedback() async {
    if (_activity.id == null) return;
    try {
      final feedback = await ReadinessService().getFeedback(_activity.id!);
      if (mounted) setState(() => _rpe = feedback?.rpe);
    } catch (_) {}
  }

  Future<void> _saveRpe(int value) async {
    if (_activity.id == null) return;
    setState(() {
      _rpe = value;
      _isSavingRecovery = true;
    });
    try {
      await ReadinessService().saveFeedback(
        activityId: _activity.id!,
        rpe: value,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.translate('error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingRecovery = false);
    }
  }

  Future<void> _updateActivityInfo({
    required String name,
    required String notes,
  }) async {
    if (_activity.id == null) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('activities')
          .update({
            'name': name.isEmpty ? null : name,
            'notes': notes.isEmpty ? null : notes,
          })
          .eq('id', _activity.id!);

      setState(() {
        _activity = Activity(
          id: _activity.id,
          userId: _activity.userId,
          startedAt: _activity.startedAt,
          distanceKm: _activity.distanceKm,
          durationMin: _activity.durationMin,
          avgHr: _activity.avgHr,
          elevationGainM: _activity.elevationGainM,
          name: name.isEmpty ? null : name,
          notes: notes.isEmpty ? null : notes,
          dataPoints: _activity.dataPoints,
          startLat: _activity.startLat,
          startLon: _activity.startLon,
          weatherSummary: _activity.weatherSummary,
          temperatureC: _activity.temperatureC,
          aqi: _activity.aqi,
          weatherFetchedAt: _activity.weatherFetchedAt,
          weatherJson: _activity.weatherJson,
          shoeId: _activity.shoeId,
        );
        _hasChanged = true;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.translate('update_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.translate('error')}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteActivity() async {
    if (_activity.id == null) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('activities')
          .delete()
          .eq('id', _activity.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.translate('delete_success')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Pop page indicating deletion
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.translate('error')}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showEditNotesDialog() {
    final theme = Theme.of(context);
    final nameController = TextEditingController(text: _activity.name ?? '');
    final notesController = TextEditingController(
      text: _activity.notes != null && _activity.notes != _activity.name
          ? _activity.notes!
          : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          context.translate('edit_info'),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: context.translate('activity_name'),
                hintText: context.translate('activity_name_hint'),
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: context.translate('notes'),
                hintText: context.translate('enter_notes_hint'),
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.translate('cancel'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newNotes = notesController.text.trim();
              Navigator.pop(context);
              await _updateActivityInfo(name: newName, notes: newNotes);
            },
            child: Text(
              context.translate('save'),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteActivity() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          context.translate('delete_activity'),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          context.translate('delete_activity_confirm'),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.translate('cancel'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteActivity();
            },
            child: Text(
              context.translate('delete'),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dataPoints = _activity.dataPoints;
    final List<double> times = _convertToList(dataPoints?['times']);
    final List<double> paces = _convertToList(dataPoints?['paces']);
    final List<double> elevations = _convertToList(dataPoints?['elevations']);
    final List<double> hrs = _convertToList(dataPoints?['hrs']);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasChanged);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => Navigator.pop(context, _hasChanged),
          ),
          title: MarqueeText(
            _activity.name ??
                _activity.notes ??
                context.translate('activity_details'),
            style: TextStyle(color: colorScheme.onSurface),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditNotesDialog();
                } else if (value == 'delete') {
                  _confirmDeleteActivity();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        context.translate('edit_info'),
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text(
                        context.translate('delete_activity'),
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
              color: colorScheme.surface,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AICoachPage(initialActivity: _activity),
              ),
            );
          },
          backgroundColor: colorScheme.primary,
          child: const Icon(
            Icons.tips_and_updates_outlined,
            color: Colors.white,
          ),
        ),
        body: Stack(
          children: [
            SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: sportPlatformGradient(context),
                ),
              ),
            ),
            SafeArea(
              child: ResponsiveContent(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width > 900
                        ? 20.0
                        : 16.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isSaving) ...[
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 24),
                      ],
                      // Thời gian thực hiện (bắt đầu - kết thúc)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatStartEnd(
                                _activity.startedAt,
                                _activity.durationMin,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildSummaryHeader(context),
                      const SizedBox(height: 24),
                      _buildRecoveryFeedbackCard(context),
                      const SizedBox(height: 24),
                      if (_activity.weatherSummary != null ||
                          _activity.temperatureC != null ||
                          _activity.aqi != null) ...[
                        _buildWeatherCard(context),
                        const SizedBox(height: 24),
                      ],
                      _buildShoeCard(context),
                      const SizedBox(height: 24),
                      if (paces.isNotEmpty) ...[
                        ActivityChart(
                          title: context.translate('pace_title'),
                          xValues: times,
                          yValues: paces,
                          color: const Color(0xFFFA6B27),
                          yAxisLabel: context.translate('min_km'),
                          isPace: true,
                          activeX: _activeTime,
                          onXSelected: (val) =>
                              setState(() => _activeTime = val),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (hrs.isNotEmpty) ...[
                        ActivityChart(
                          title: context.translate('heart_rate'),
                          xValues: times,
                          yValues: hrs,
                          color: Colors.redAccent,
                          yAxisLabel: context.translate('bpm'),
                          activeX: _activeTime,
                          onXSelected: (val) =>
                              setState(() => _activeTime = val),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (elevations.isNotEmpty) ...[
                        ActivityChart(
                          title: context.translate('elevation'),
                          xValues: times,
                          yValues: elevations,
                          color: const Color(0xFF3CABFF),
                          yAxisLabel: context.translate('m'),
                          activeX: _activeTime,
                          onXSelected: (val) =>
                              setState(() => _activeTime = val),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_activity.notes != null &&
                          _activity.notes!.isNotEmpty &&
                          _activity.notes != _activity.name) ...[
                        Text(
                          context.translate('notes'),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        glassCard(
                          context: context,
                          child: Text(
                            _activity.notes!,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                      if (_activity.createdAt != null) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.download_done,
                                size: 14,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${context.translate('imported_time')}: ${DateFormat('HH:mm dd/MM/yyyy').format(_activity.createdAt!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryFeedbackCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return glassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sentiment_satisfied_alt, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                context.translate('post_run_feeling'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_isSavingRecovery)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.translate('rpe_hint'),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(10, (index) {
              final value = index + 1;
              return ChoiceChip(
                label: Text('$value'),
                selected: _rpe == value,
                onSelected: _isSavingRecovery ? null : (_) => _saveRpe(value),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    WeatherSnapshot? snapshot;
    if (_activity.weatherJson != null) {
      snapshot = WeatherSnapshot.fromJson(_activity.weatherJson!);
    } else if (_activity.temperatureC != null ||
        _activity.aqi != null ||
        _activity.weatherSummary != null) {
      snapshot = WeatherSnapshot(
        fetchedAt: _activity.weatherFetchedAt ?? DateTime.now(),
        temperatureC: _activity.temperatureC,
        aqi: _activity.aqi,
        description: _activity.weatherSummary,
      );
    }

    if (snapshot == null) return const SizedBox.shrink();

    return glassCard(
      context: context,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('environment_conditions'),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (snapshot.icon != null) ...[
                Image.network(
                  'https://openweathermap.org/img/wn/${snapshot.icon}@2x.png',
                  width: 48,
                  height: 48,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snapshot.temperatureC?.toStringAsFixed(1) ?? '--'}°C • ${snapshot.summary ?? snapshot.description ?? context.translate('weather')}',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.air,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AQI ${snapshot.aqi ?? '--'}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: snapshot.aqiColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            snapshot.aqiLabel,
                            style: TextStyle(
                              color: snapshot.aqiColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              _showAQIDialog(context, snapshot!.locationName),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Icon(
                              Icons.error_outline,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (snapshot.windKph != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.wind_power,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.windKph!.toStringAsFixed(1)} ${context.translate('km_h')}',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return glassCard(
      context: context,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  context.translate('distance'),
                  '${_activity.distanceKm.toStringAsFixed(2)} km',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  context,
                  context.translate('time'),
                  _formatDuration(_activity.durationMin),
                ),
              ),
            ],
          ),
          Divider(
            color: colorScheme.outline.withValues(alpha: 0.1),
            height: 32,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                context,
                context.translate('avg_pace'),
                _formatPace(_activity.durationMin / _activity.distanceKm),
              ),
              _buildStatItem(
                context,
                context.translate('elevation_gain'),
                '${_activity.elevationGainM?.toStringAsFixed(0) ?? 0} m',
              ),
            ],
          ),
          if (_activity.avgHr != null || _activity.avgCadence != null) ...[
            Divider(
              color: colorScheme.outline.withValues(alpha: 0.1),
              height: 32,
            ),
            Row(
              children: [
                if (_activity.avgHr != null)
                  Expanded(
                    child: _buildStatItem(
                      context,
                      context.translate('avg_hr'),
                      '${_activity.avgHr} bpm',
                    ),
                  ),
                if (_activity.avgCadence != null)
                  Expanded(
                    child: _buildStatItem(
                      context,
                      context.translate('avg_cadence'),
                      '${_activity.avgCadence} spm',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDuration(double minutes) {
    int h = minutes ~/ 60;
    int m = minutes.toInt() % 60;
    int s = ((minutes - minutes.toInt()) * 60).round();
    if (h > 0) {
      return "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  String _formatPace(double paceDecimal) {
    if (paceDecimal.isInfinite || paceDecimal.isNaN) return "-:--";
    int minutes = paceDecimal.floor();
    int seconds = ((paceDecimal - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  List<double> _convertToList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => (e as num).toDouble()).toList();
    }
    return [];
  }

  Future<void> _fetchShoeInfo() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final shoesRes = await Supabase.instance.client
          .from('shoes')
          .select()
          .order('name');
      final shoesList = (shoesRes as List)
          .map((json) => Shoe.fromJson(json))
          .toList();

      Shoe? currentShoe;
      if (_activity.shoeId != null) {
        final index = shoesList.indexWhere((s) => s.id == _activity.shoeId);
        if (index != -1) {
          currentShoe = shoesList[index];
        }
      }

      setState(() {
        _shoes = shoesList;
        _currentShoe = currentShoe;
      });
    } catch (e) {
      debugPrint('Error fetching shoe info on detail page: $e');
    }
  }

  Future<void> _updateActivityShoe(String? shoeId) async {
    if (_activity.id == null) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('activities')
          .update({'shoe_id': shoeId})
          .eq('id', _activity.id!);

      final updatedActivity = Activity(
        id: _activity.id,
        userId: _activity.userId,
        startedAt: _activity.startedAt,
        distanceKm: _activity.distanceKm,
        durationMin: _activity.durationMin,
        avgHr: _activity.avgHr,
        elevationGainM: _activity.elevationGainM,
        name: _activity.name,
        notes: _activity.notes,
        dataPoints: _activity.dataPoints,
        startLat: _activity.startLat,
        startLon: _activity.startLon,
        weatherSummary: _activity.weatherSummary,
        temperatureC: _activity.temperatureC,
        aqi: _activity.aqi,
        weatherFetchedAt: _activity.weatherFetchedAt,
        weatherJson: _activity.weatherJson,
        shoeId: shoeId,
      );

      final index = _shoes.indexWhere((s) => s.id == shoeId);
      final newShoe = (index != -1) ? _shoes[index] : null;

      setState(() {
        _activity = updatedActivity;
        _currentShoe = newShoe;
        _hasChanged = true;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      debugPrint('Error updating activity shoe: $e');
    }
  }

  Widget _buildShoeCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeShoes = _shoes.where((s) => s.isActive).toList();

    return glassCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('shoe_tracker'),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.shoePrints,
                      color: _currentShoe != null
                          ? colorScheme.primary
                          : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentShoe != null
                            ? '${_currentShoe!.name} (${_currentShoe!.brand ?? ''})'
                            : context.translate('no_shoes_yet'),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButton<String>(
                value: _activity.shoeId,
                hint: Text(
                  context.translate('select_shoe'),
                  style: const TextStyle(fontSize: 12),
                ),
                underline: const SizedBox(),
                icon: Icon(Icons.edit, color: colorScheme.primary, size: 18),
                onChanged: (String? newValue) async {
                  await _updateActivityShoe(newValue);
                },
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      context.translate('no_shoe'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  ...activeShoes.map((shoe) {
                    return DropdownMenuItem<String>(
                      value: shoe.id,
                      child: Text(
                        shoe.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          if (_currentShoe != null && _currentShoe!.distanceKm >= 500.0) ...[
            const SizedBox(height: 10),
            Text(
              context.translate('shoe_replace_warning'),
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatStartEnd(DateTime start, double durationMin) {
    final end = start.add(Duration(seconds: (durationMin * 60).round()));
    final startFmt = DateFormat('HH:mm');
    final endFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('dd/MM/yyyy');
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '${startFmt.format(start)} - ${endFmt.format(end)} ${dateFmt.format(start)}';
    } else {
      return '${DateFormat('HH:mm dd/MM/yyyy').format(start)} - ${DateFormat('HH:mm dd/MM/yyyy').format(end)}';
    }
  }

  void _showAQIDialog(BuildContext context, String? locationName) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.translate('aqi_info_title'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (locationName != null && locationName.isNotEmpty) ...[
              Text(
                context.translate('aqi_monitoring_station'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                locationName,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              '${context.translate('aqi_warning_title')}:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.translate('aqi_warning_content'),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('close')),
          ),
        ],
      ),
    );
  }
}
