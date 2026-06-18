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

  // ── Production safeguards (no app release needed to flip) ──────────────
  /// Builds below this are forced to update (compared to build number).
  static const minSupportedBuild = 'min_supported_build';

  /// Hard kill-switch: when true, the whole app shows a maintenance screen.
  static const maintenanceMode = 'maintenance_mode';
  static const maintenanceMessage = 'maintenance_message';
  static const updateMessage = 'update_message';

  static const defaults = <String, dynamic>{
    inviteTemplate:
        '{name} said {count} things about you on Known 👀 — unlock them: {link}',
    campaignTemplate:
        "I'd love your honest feedback — it takes 2 minutes and you can stay anonymous: {link}",
    feedbackFridayEnabled: true,
    minSupportedBuild: 0,
    maintenanceMode: false,
    maintenanceMessage:
        'Known is down for quick maintenance. Please check back shortly.',
    updateMessage:
        'A new version of Known is available with improvements and fixes.',
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
