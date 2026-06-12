import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Remote Config — growth levers that should be tunable without an app
/// release: invite copy A/B variants and event flags.
///
/// Placeholders supported in invite templates:
///   {name}  — sender display name (or "Someone")
///   {count} — number of things they said (tags + comment)
///   {link}  — the invite deep link
class RemoteConfigKeys {
  static const inviteTemplate = 'invite_template';
  static const campaignTemplate = 'campaign_template';
  static const feedbackFridayEnabled = 'feedback_friday_enabled';

  static const defaults = <String, dynamic>{
    inviteTemplate:
        '{name} said {count} things about you on The Wall 👀 — unlock them: {link}',
    campaignTemplate:
        "I'd love your honest feedback — it takes 2 minutes and you can stay anonymous: {link}",
    feedbackFridayEnabled: true,
  };
}

final remoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) {
  final rc = FirebaseRemoteConfig.instance;
  return rc;
});

/// Call once at startup (non-blocking; falls back to defaults on failure).
Future<void> initRemoteConfig() async {
  try {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setDefaults(RemoteConfigKeys.defaults);
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 8),
      minimumFetchInterval: const Duration(hours: 6),
    ));
    await rc.fetchAndActivate();
  } catch (_) {
    // Defaults already set — growth copy just won't be remotely tunable
    // this session.
  }
}

/// Render an invite/campaign template with its placeholders.
String renderTemplate(
  String template, {
  String? name,
  int count = 0,
  required String link,
}) {
  var text = template
      .replaceAll('{name}', (name == null || name.isEmpty) ? 'Someone' : name)
      .replaceAll('{count}', '$count')
      .replaceAll('{link}', link);
  // Grammar guard: "said 1 things" reads broken — degrade gracefully.
  if (count < 2) {
    text = text.replaceAll('said $count things about you', 'left you feedback');
  }
  return text;
}
