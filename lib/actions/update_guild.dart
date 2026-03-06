import 'package:nyxx/nyxx.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> updateGuildAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'guildId': ''};
    }

    final builder = GuildUpdateBuilder();

    if (payload.containsKey('name')) {
      final name = payload['name']?.toString().trim();
      builder.name = (name != null && name.isNotEmpty) ? name : null;
    }

    if (payload.containsKey('description')) {
      builder.description = payload['description']?.toString();
    }

    if (payload.containsKey('preferredLocale')) {
      final localeRaw = payload['preferredLocale']?.toString().trim() ?? '';
      if (localeRaw.isNotEmpty) {
        builder.preferredLocale = Locale.parse(localeRaw);
      }
    }

    if (payload.containsKey('premiumProgressBarEnabled')) {
      final raw = payload['premiumProgressBarEnabled'];
      builder.premiumProgressBarEnabled =
          raw is bool ? raw : raw?.toString().toLowerCase() == 'true';
    }

    if (payload.containsKey('afkTimeoutSeconds')) {
      final seconds = int.tryParse(
        (payload['afkTimeoutSeconds'] ?? '').toString(),
      );
      if (seconds != null && seconds >= 0) {
        builder.afkTimeout = Duration(seconds: seconds);
      }
    }

    if (payload.containsKey('afkChannelId')) {
      builder.afkChannelId = _toSnowflake(payload['afkChannelId']);
    }
    if (payload.containsKey('systemChannelId')) {
      builder.systemChannelId = _toSnowflake(payload['systemChannelId']);
    }
    if (payload.containsKey('rulesChannelId')) {
      builder.rulesChannelId = _toSnowflake(payload['rulesChannelId']);
    }
    if (payload.containsKey('publicUpdatesChannelId')) {
      builder.publicUpdatesChannelId = _toSnowflake(
        payload['publicUpdatesChannelId'],
      );
    }
    if (payload.containsKey('safetyAlertsChannelId')) {
      builder.safetyAlertsChannelId = _toSnowflake(
        payload['safetyAlertsChannelId'],
      );
    }

    if (payload.containsKey('verificationLevel')) {
      final raw = int.tryParse((payload['verificationLevel'] ?? '').toString());
      if (raw != null) {
        builder.verificationLevel = VerificationLevel(raw);
      }
    }
    if (payload.containsKey('defaultMessageNotificationLevel')) {
      final raw = int.tryParse(
        (payload['defaultMessageNotificationLevel'] ?? '').toString(),
      );
      if (raw != null) {
        builder.defaultMessageNotificationLevel = MessageNotificationLevel(raw);
      }
    }
    if (payload.containsKey('explicitContentFilterLevel')) {
      final raw = int.tryParse(
        (payload['explicitContentFilterLevel'] ?? '').toString(),
      );
      if (raw != null) {
        builder.explicitContentFilterLevel = ExplicitContentFilterLevel(raw);
      }
    }

    final reason = payload['reason']?.toString().trim();
    final updated = await client.guilds.update(
      guildId,
      builder,
      auditLogReason: (reason != null && reason.isNotEmpty) ? reason : null,
    );

    return {
      'guildId': updated.id.toString(),
      'name': updated.name,
      'description': updated.description ?? '',
    };
  } catch (error) {
    return {'error': 'Failed to update guild: $error', 'guildId': ''};
  }
}
