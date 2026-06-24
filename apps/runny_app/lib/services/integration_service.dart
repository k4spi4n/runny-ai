import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class IntegrationService {
  final _supabase = Supabase.instance.client;

  // Placeholder Strava Config (In a real app, these should be in .env)
  final String _stravaClientId = 'YOUR_STRAVA_CLIENT_ID';
  final String _stravaRedirectUri = 'http://localhost:3000/'; // Adjust for production

  Future<void> connectStrava() async {
    final authUrl = Uri.parse(
      'https://www.strava.com/oauth/authorize'
      '?client_id=$_stravaClientId'
      '&redirect_uri=$_stravaRedirectUri'
      '&response_type=code'
      '&scope=activity:read_all,profile:read_all'
    );

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch Strava auth URL';
    }
  }

  Future<void> connectGarmin() async {
    // Garmin OAuth is more complex (OAuth 1.0a or 2.0 depending on API)
    // For now, we'll just show a placeholder URL or message
    final authUrl = Uri.parse('https://connect.garmin.com/oauth/authorize');
    
    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch Garmin auth URL';
    }
  }

  Future<void> disconnectStrava() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('profiles').update({
      'strava_id': null,
      'strava_access_token': null,
      'strava_refresh_token': null,
      'strava_expires_at': null,
    }).eq('id', user.id);
  }

  Future<void> disconnectGarmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('profiles').update({
      'garmin_id': null,
    }).eq('id', user.id);
  }
}
