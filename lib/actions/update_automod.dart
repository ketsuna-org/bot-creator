import 'package:nyxx/nyxx.dart';

const _keywordRuleName = 'BotCreator - Keyword Filter';
const _mentionRuleName = 'BotCreator - Mention Limit';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return const [];
  }
  return text
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();
}

List<Snowflake> _toSnowflakeList(dynamic value) {
  return _toStringList(
    value,
  ).map((entry) => _toSnowflake(entry)).whereType<Snowflake>().toList();
}

AutoModerationRule? _findRuleByName(
  List<AutoModerationRule> rules,
  String name,
) {
  for (final rule in rules) {
    if (rule.name == name) {
      return rule;
    }
  }
  return null;
}

Future<Map<String, String>> updateAutoModAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'status': ''};
    }

    final enabledRaw = payload['enabled'];
    final enabled =
        enabledRaw is bool
            ? enabledRaw
            : (enabledRaw?.toString().toLowerCase() != 'false');

    final filterWords = _toStringList(payload['filterWords']);
    final exemptRoleIds = _toSnowflakeList(payload['allowedRoles']);
    final maxMentionsRaw = int.tryParse(
      (payload['maxMentions'] ?? '').toString(),
    );
    final maxMentions = (maxMentionsRaw ?? 5).clamp(1, 50);
    final reason = payload['reason']?.toString().trim();

    final guild = await client.guilds.get(guildId);
    final existingRules = await guild.autoModerationRules.list();

    final keywordRule = _findRuleByName(existingRules, _keywordRuleName);
    final mentionRule = _findRuleByName(existingRules, _mentionRuleName);

    final actions = <AutoModerationActionBuilder>[
      AutoModerationActionBuilder.blockMessage(),
    ];

    if (filterWords.isNotEmpty) {
      if (keywordRule == null) {
        await guild.autoModerationRules.create(
          AutoModerationRuleBuilder.keyword(
            name: _keywordRuleName,
            eventType: AutoModerationEventType.messageSend,
            actions: actions,
            isEnabled: enabled,
            exemptRoleIds: exemptRoleIds,
            keywordFilter: filterWords,
          ),
          auditLogReason:
              (reason != null && reason.isNotEmpty)
                  ? reason
                  : 'Update auto-moderation keyword rule',
        );
      } else {
        await keywordRule.update(
          AutoModerationRuleUpdateBuilder(
            name: _keywordRuleName,
            eventType: AutoModerationEventType.messageSend,
            actions: actions,
            isEnabled: enabled,
            exemptRoleIds: exemptRoleIds,
            metadata: TriggerMetadataBuilder(keywordFilter: filterWords),
          ),
        );
      }
    } else if (keywordRule != null) {
      await keywordRule.update(
        AutoModerationRuleUpdateBuilder(
          isEnabled: false,
          exemptRoleIds: exemptRoleIds,
        ),
      );
    }

    if (mentionRule == null) {
      await guild.autoModerationRules.create(
        AutoModerationRuleBuilder.mentionSpam(
          name: _mentionRuleName,
          eventType: AutoModerationEventType.messageSend,
          actions: actions,
          isEnabled: enabled,
          exemptRoleIds: exemptRoleIds,
          mentionTotalLimit: maxMentions,
        ),
        auditLogReason:
            (reason != null && reason.isNotEmpty)
                ? reason
                : 'Update auto-moderation mention rule',
      );
    } else {
      await mentionRule.update(
        AutoModerationRuleUpdateBuilder(
          name: _mentionRuleName,
          eventType: AutoModerationEventType.messageSend,
          actions: actions,
          isEnabled: enabled,
          exemptRoleIds: exemptRoleIds,
          metadata: TriggerMetadataBuilder(mentionTotalLimit: maxMentions),
        ),
      );
    }

    return {'status': 'OK'};
  } catch (error) {
    return {'error': 'Failed to update auto-moderation: $error', 'status': ''};
  }
}
