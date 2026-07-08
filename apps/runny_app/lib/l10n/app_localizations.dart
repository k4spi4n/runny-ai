import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  Map<String, String>? _localizedStrings;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Future<bool> load() async {
    try {
      String jsonString = await rootBundle.loadString(
        'lib/l10n/locales/${locale.languageCode}.json',
      );
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });
      return true;
    } catch (e) {
      debugPrint('Error loading localization: $e');
      _localizedStrings = {};
      return false;
    }
  }

  String translate(String key, [List<String>? args]) {
    if (_localizedStrings == null || !_localizedStrings!.containsKey(key)) {
      return _format(
        _fallbackStrings[locale.languageCode]?[key] ??
            _fallbackStrings['en']?[key] ??
            key,
        args,
      );
    }
    return _format(_localizedStrings![key]!, args);
  }

  String _format(String translation, List<String>? args) {
    if (args != null && args.isNotEmpty) {
      for (var i = 0; i < args.length; i++) {
        translation = translation.replaceFirst('%s', args[i]);
      }
    }
    return translation;
  }

  static const Map<String, Map<String, String>> _fallbackStrings = {
    'en': {
      'landing_tagline': 'AI-POWERED RUNNING COACH',
      'landing_hero_title': 'Run smarter with your personal AI coach',
      'landing_hero_subtitle':
          'Track every run, get personalized training plans, and reach your goals with an AI coach that understands you.',
      'landing_feature_ai_title': 'AI Coach',
      'landing_feature_ai_desc':
          'Chat for advice, auto-generated training plans, and deep run analysis.',
      'landing_feature_tracking_title': 'Tracking & Charts',
      'landing_feature_tracking_desc':
          'Pace, heart rate and elevation with synced interactive charts.',
      'landing_feature_community_title': 'Community',
      'landing_feature_community_desc':
          'Leaderboards, badges and running partner matching.',
      'landing_footer': 'Built with care for the running community.',
      'landing_nav_features': 'Features',
      'landing_nav_how_it_works': 'How It Works',
      'landing_nav_tech_stack': 'Tech Stack',
      'landing_nav_menu': 'Menu',
      'landing_badge': 'AI RUNNING PLATFORM',
      'landing_slogan': 'Run smarter with an AI coach',
      'landing_description':
          'Plan, track, and improve every run with AI insights, performance data, and community motivation.',
      'landing_explore_features': 'View features',
      'landing_metric_plan_ready': 'plan ready',
      'landing_metric_target_pace': 'target pace',
      'landing_metric_goal_trend': 'goal trend',
      'landing_mockup_insight_title': 'AI Coach Insight',
      'landing_mockup_insight_desc': 'Recovery-aware tempo adjustment',
      'landing_mockup_distance': 'Distance',
      'landing_mockup_pace': 'Pace',
      'landing_mockup_weekly_goal': 'Weekly goal',
      'landing_mockup_training_load': 'Training load',
      'landing_mockup_next': 'Next: 35 min easy run in Zone 2.',
      'landing_feature_ai_bullet_1': 'Personal coaching chat and run analysis.',
      'landing_feature_ai_bullet_2':
          'Adaptive plans based on goals and fitness.',
      'landing_feature_tracking_full_title': 'Tracking & Analytics',
      'landing_feature_tracking_bullet_1':
          'Distance, pace, time, elevation, and heart rate.',
      'landing_feature_tracking_bullet_2':
          'Activity history, charts, and route maps.',
      'landing_feature_social_title': 'Community & Rewards',
      'landing_feature_social_bullet_1': 'Leaderboards and achievement badges.',
      'landing_feature_social_bullet_2': 'Partner matching by pace or area.',
      'landing_feature_health_title': 'Health & Nutrition',
      'landing_feature_health_bullet_1': 'Weight, BMI, and recovery signals.',
      'landing_feature_health_bullet_2':
          'Nutrition guidance from activity level.',
      'landing_features_kicker': 'FEATURES',
      'landing_features_title': 'Focused tools for better running',
      'landing_features_desc':
          'Runny AI brings coaching, tracking, motivation, and health data into one clean experience.',
      'landing_value_kicker': 'WHY RUNNY AI',
      'landing_value_title': 'Train with clearer feedback',
      'landing_value_desc':
          'Turn running data into practical next steps for every week of training.',
      'landing_value_personal_title': 'Personalized training',
      'landing_value_personal_desc':
          'Plans adapt to your goal, metrics, and recent runs.',
      'landing_value_performance_title': 'Performance optimization',
      'landing_value_performance_desc':
          'Insights help balance pace, load, and progress.',
      'landing_value_motivation_title': 'Motivation that sticks',
      'landing_value_motivation_desc':
          'Achievements and community keep momentum visible.',
      'landing_value_platform_title': 'One connected platform',
      'landing_value_platform_desc':
          'Workout, health, nutrition, weather, Strava, and AI in one place.',
      'landing_value_statement':
          'Runny AI gives runners a clear next step before training, after each run, and during long-term progress.',
      'landing_chip_ai_coach': 'AI Coach',
      'landing_chip_activity': 'Activity Data',
      'landing_chip_health': 'Health Signals',
      'landing_chip_community': 'Community',
      'landing_how_kicker': 'HOW IT WORKS',
      'landing_how_title': 'How Runny AI works',
      'landing_how_desc':
          'A simple coaching loop from goal setup to measurable progress.',
      'landing_step_1_title': 'Set a goal',
      'landing_step_1_desc':
          'Choose your target distance, habit, or race plan.',
      'landing_step_2_title': 'Connect your data',
      'landing_step_2_desc':
          'Runny AI reads metrics, history, pace, and recovery context.',
      'landing_step_3_title': 'Get your plan',
      'landing_step_3_desc':
          'AI suggests workouts and adjustments that fit your timeline.',
      'landing_step_4_title': 'Improve weekly',
      'landing_step_4_desc': 'Track runs, review insights, and keep momentum.',
      'landing_tech_kicker': 'TECH STACK',
      'landing_tech_title': 'Modern product foundation',
      'landing_tech_desc':
          'Built with Flutter, Supabase, PostgreSQL, AI integrations, Strava, and weather services.',
      'landing_tech_flutter_desc': 'Cross-platform app experience.',
      'landing_tech_supabase_desc': 'Authentication and backend services.',
      'landing_tech_postgres_desc': 'Structured training and profile data.',
      'landing_tech_ai_desc': 'Coaching, analysis, and recommendations.',
      'landing_tech_strava_desc': 'Activity import and sync workflows.',
      'landing_tech_weather_desc': 'Weather context for outdoor runs.',
      'landing_cta_title': 'Ready to run smarter?',
      'landing_cta_desc': 'Start your AI-powered running journey.',
      'landing_footer_analytics': 'Analytics',
      'landing_footer_desc':
          'Runny AI combines coaching, analytics, motivation, and health data for runners.',
      'landing_footer_copyright':
          'Copyright 2026 Runny AI. Built with care for the running community.',
      'edit': 'Edit',
      'manual_workout_create_title': 'Add manual workout',
      'manual_workout_edit_title': 'Edit workout',
      'manual_workout_subtitle':
          'Plan a workout yourself and keep it in the same training schedule.',
      'manual_workout_add_tooltip': 'Add manual workout',
      'manual_workout_title_label': 'Workout name',
      'manual_workout_title_hint': 'Easy run, tempo session...',
      'manual_workout_title_required': 'Please enter a workout name.',
      'manual_workout_date_label': 'Workout date',
      'manual_workout_start_time_label': 'Start time',
      'manual_workout_duration_label': 'Expected duration',
      'manual_workout_distance_label': 'Target distance',
      'manual_workout_type_label': 'Workout type',
      'manual_workout_notes_label': 'Personal notes',
      'manual_workout_notes_hint': 'Add your own cues, route, or reminders...',
      'manual_workout_number_invalid':
          'Please enter a valid non-negative number.',
      'manual_workout_save_btn': 'Save workout',
      'manual_workout_update_btn': 'Update workout',
      'manual_workout_created': 'Manual workout saved.',
      'manual_workout_updated': 'Workout updated.',
      'manual_workout_deleted': 'Workout deleted.',
      'manual_workout_delete_title': 'Delete workout',
      'manual_workout_delete_confirm':
          'Are you sure you want to delete this manual workout? This action cannot be undone.',
      'manual_workout_schema_missing':
          'The database has not been updated for manual workouts yet. Please run the latest Supabase migration, then try again.',
      'source_manual': 'Manual',
      'source_ai': 'AI',
      'minutes_short': 'min',
      'workout_type_easy_run': 'Easy run',
      'workout_type_long_run': 'Long run',
      'workout_type_interval': 'Interval',
      'workout_type_tempo': 'Tempo',
      'workout_type_recovery': 'Recovery',
      'run_timer': 'Run timer',
      'timer_not_started': 'Not started',
      'timer_running': 'Running',
      'timer_paused': 'Paused',
      'timer_finished': 'Finished',
    },
    'vi': {
      'landing_tagline': 'HUẤN LUYỆN VIÊN CHẠY BỘ AI',
      'landing_hero_title': 'Chạy thông minh hơn cùng HLV AI cá nhân',
      'landing_hero_subtitle':
          'Theo dõi mọi buổi chạy, nhận giáo án tập luyện cá nhân hóa và chinh phục mục tiêu cùng một HLV AI thật sự hiểu bạn.',
      'landing_feature_ai_title': 'HLV AI',
      'landing_feature_ai_desc':
          'Trò chuyện tư vấn, tự động lập giáo án và phân tích buổi chạy chuyên sâu.',
      'landing_feature_tracking_title': 'Theo dõi & Biểu đồ',
      'landing_feature_tracking_desc':
          'Pace, nhịp tim, độ cao với biểu đồ tương tác đồng bộ.',
      'landing_feature_community_title': 'Cộng đồng',
      'landing_feature_community_desc':
          'Bảng xếp hạng, huy hiệu và ghép đôi bạn chạy.',
      'landing_footer': 'Được phát triển tận tâm cho cộng đồng chạy bộ.',
      'landing_nav_features': 'Tính năng',
      'landing_nav_how_it_works': 'Cách hoạt động',
      'landing_nav_tech_stack': 'Công nghệ',
      'landing_nav_menu': 'Menu',
      'landing_badge': 'NỀN TẢNG CHẠY BỘ AI',
      'landing_slogan': 'Chạy thông minh hơn với AI Coach',
      'landing_description':
          'Lập kế hoạch, theo dõi và cải thiện từng buổi chạy bằng AI, dữ liệu hiệu suất và động lực cộng đồng.',
      'landing_explore_features': 'Xem tính năng',
      'landing_metric_plan_ready': 'kế hoạch sẵn sàng',
      'landing_metric_target_pace': 'pace mục tiêu',
      'landing_metric_goal_trend': 'xu hướng mục tiêu',
      'landing_mockup_insight_title': 'Nhận xét từ AI Coach',
      'landing_mockup_insight_desc': 'Điều chỉnh tempo theo phục hồi',
      'landing_mockup_distance': 'Quãng đường',
      'landing_mockup_pace': 'Pace',
      'landing_mockup_weekly_goal': 'Mục tiêu tuần',
      'landing_mockup_training_load': 'Tải tập luyện',
      'landing_mockup_next': 'Tiếp theo: chạy nhẹ 35 phút ở Zone 2.',
      'landing_feature_ai_bullet_1': 'Chat huấn luyện và phân tích buổi chạy.',
      'landing_feature_ai_bullet_2':
          'Kế hoạch thích ứng theo mục tiêu và thể trạng.',
      'landing_feature_tracking_full_title': 'Theo dõi & Phân tích',
      'landing_feature_tracking_bullet_1':
          'Quãng đường, pace, thời gian, độ cao và nhịp tim.',
      'landing_feature_tracking_bullet_2':
          'Lịch sử, biểu đồ và bản đồ hành trình.',
      'landing_feature_social_title': 'Cộng đồng & Thành tích',
      'landing_feature_social_bullet_1':
          'Bảng xếp hạng và huy hiệu thành tích.',
      'landing_feature_social_bullet_2':
          'Ghép đôi bạn chạy theo pace hoặc khu vực.',
      'landing_feature_health_title': 'Sức khỏe & Dinh dưỡng',
      'landing_feature_health_bullet_1': 'Cân nặng, BMI và tín hiệu phục hồi.',
      'landing_feature_health_bullet_2': 'Gợi ý dinh dưỡng theo mức vận động.',
      'landing_features_kicker': 'TÍNH NĂNG',
      'landing_features_title': 'Công cụ tập trung cho runner',
      'landing_features_desc':
          'Runny AI kết hợp huấn luyện, theo dõi, động lực và dữ liệu sức khỏe trong một trải nghiệm gọn gàng.',
      'landing_value_kicker': 'VÌ SAO CHỌN RUNNY AI',
      'landing_value_title': 'Tập luyện với phản hồi rõ ràng hơn',
      'landing_value_desc':
          'Biến dữ liệu chạy bộ thành bước tiếp theo thực tế cho từng tuần tập luyện.',
      'landing_value_personal_title': 'Tập luyện cá nhân hóa',
      'landing_value_personal_desc':
          'Kế hoạch thích ứng theo mục tiêu, chỉ số và các buổi chạy gần đây.',
      'landing_value_performance_title': 'Tối ưu hiệu suất',
      'landing_value_performance_desc':
          'Insight giúp cân bằng pace, tải tập và tiến bộ.',
      'landing_value_motivation_title': 'Động lực bền vững',
      'landing_value_motivation_desc':
          'Thành tích và cộng đồng giữ động lực luôn rõ ràng.',
      'landing_value_platform_title': 'Một nền tảng kết nối',
      'landing_value_platform_desc':
          'Buổi tập, sức khỏe, dinh dưỡng, thời tiết, Strava và AI trong một nơi.',
      'landing_value_statement':
          'Runny AI đưa ra bước tiếp theo rõ ràng trước buổi tập, sau mỗi lần chạy và trong tiến trình dài hạn.',
      'landing_chip_ai_coach': 'AI Coach',
      'landing_chip_activity': 'Dữ liệu hoạt động',
      'landing_chip_health': 'Tín hiệu sức khỏe',
      'landing_chip_community': 'Cộng đồng',
      'landing_how_kicker': 'CÁCH HOẠT ĐỘNG',
      'landing_how_title': 'Runny AI hoạt động thế nào',
      'landing_how_desc':
          'Một vòng huấn luyện đơn giản từ mục tiêu đến tiến bộ đo được.',
      'landing_step_1_title': 'Đặt mục tiêu',
      'landing_step_1_desc': 'Chọn cự ly, thói quen hoặc kế hoạch race.',
      'landing_step_2_title': 'Kết nối dữ liệu',
      'landing_step_2_desc': 'Runny AI đọc chỉ số, lịch sử, pace và phục hồi.',
      'landing_step_3_title': 'Nhận kế hoạch',
      'landing_step_3_desc':
          'AI gợi ý bài tập và điều chỉnh theo lịch của bạn.',
      'landing_step_4_title': 'Tiến bộ mỗi tuần',
      'landing_step_4_desc': 'Theo dõi buổi chạy, xem insight và giữ nhịp tập.',
      'landing_tech_kicker': 'CÔNG NGHỆ',
      'landing_tech_title': 'Nền tảng sản phẩm hiện đại',
      'landing_tech_desc':
          'Xây dựng với Flutter, Supabase, PostgreSQL, tích hợp AI, Strava và dịch vụ thời tiết.',
      'landing_tech_flutter_desc': 'Trải nghiệm app đa nền tảng.',
      'landing_tech_supabase_desc': 'Xác thực và dịch vụ backend.',
      'landing_tech_postgres_desc': 'Dữ liệu tập luyện và hồ sơ có cấu trúc.',
      'landing_tech_ai_desc': 'Huấn luyện, phân tích và đề xuất.',
      'landing_tech_strava_desc': 'Nhập và đồng bộ hoạt động.',
      'landing_tech_weather_desc': 'Ngữ cảnh thời tiết cho chạy ngoài trời.',
      'landing_cta_title': 'Sẵn sàng chạy thông minh hơn?',
      'landing_cta_desc': 'Bắt đầu hành trình chạy bộ cùng AI.',
      'landing_footer_analytics': 'Phân tích',
      'landing_footer_desc':
          'Runny AI kết hợp huấn luyện, phân tích, động lực và dữ liệu sức khỏe cho runner.',
      'landing_footer_copyright':
          'Copyright 2026 Runny AI. Được phát triển tận tâm cho cộng đồng chạy bộ.',
      'edit': 'Sửa',
      'manual_workout_create_title': 'Thêm buổi tập thủ công',
      'manual_workout_edit_title': 'Sửa buổi tập',
      'manual_workout_subtitle':
          'Tự lên một buổi tập và giữ nó trong cùng lịch tập.',
      'manual_workout_add_tooltip': 'Thêm buổi tập thủ công',
      'manual_workout_title_label': 'Tên buổi tập',
      'manual_workout_title_hint': 'Chạy nhẹ, tempo...',
      'manual_workout_title_required': 'Vui lòng nhập tên buổi tập.',
      'manual_workout_date_label': 'Ngày tập',
      'manual_workout_start_time_label': 'Giờ bắt đầu',
      'manual_workout_duration_label': 'Thời lượng dự kiến',
      'manual_workout_distance_label': 'Quãng đường mục tiêu',
      'manual_workout_type_label': 'Loại bài tập',
      'manual_workout_notes_label': 'Ghi chú cá nhân',
      'manual_workout_notes_hint':
          'Thêm gợi ý, cung đường hoặc nhắc nhở riêng...',
      'manual_workout_number_invalid': 'Vui lòng nhập một số không âm hợp lệ.',
      'manual_workout_save_btn': 'Lưu buổi tập',
      'manual_workout_update_btn': 'Cập nhật buổi tập',
      'manual_workout_created': 'Đã lưu buổi tập thủ công.',
      'manual_workout_updated': 'Đã cập nhật buổi tập.',
      'manual_workout_deleted': 'Đã xóa buổi tập.',
      'manual_workout_delete_title': 'Xóa buổi tập',
      'manual_workout_delete_confirm':
          'Bạn có chắc muốn xóa buổi tập thủ công này? Thao tác này không thể hoàn tác.',
      'manual_workout_schema_missing':
          'Cơ sở dữ liệu chưa được cập nhật cho buổi tập thủ công. Vui lòng chạy migration Supabase mới nhất rồi thử lại.',
      'source_manual': 'Thủ công',
      'source_ai': 'AI',
      'minutes_short': 'phút',
      'workout_type_easy_run': 'Chạy nhẹ',
      'workout_type_long_run': 'Chạy dài',
      'workout_type_interval': 'Interval',
      'workout_type_tempo': 'Tempo',
      'workout_type_recovery': 'Phục hồi',
      'run_timer': 'Bộ đếm chạy',
      'timer_not_started': 'Chưa bắt đầu',
      'timer_running': 'Đang chạy',
      'timer_paused': 'Đã tạm dừng',
      'timer_finished': 'Đã hoàn thành',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'vi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsExtension on BuildContext {
  String translate(String key, [List<String>? args]) =>
      AppLocalizations.of(this)?.translate(key, args) ?? key;
}
