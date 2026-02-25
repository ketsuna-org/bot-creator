import 'package:bot_creator/actions/create_channel.dart';
import 'package:bot_creator/actions/delete_message.dart';
import 'package:bot_creator/actions/list.dart';
import 'package:bot_creator/actions/remove_channel.dart';
import 'package:bot_creator/actions/send_message.dart';
import 'package:bot_creator/actions/update_channel.dart';
import 'package:bot_creator/actions/edit_message.dart';
import 'package:bot_creator/actions/add_reaction.dart';
import 'package:bot_creator/actions/remove_reaction.dart';
import 'package:bot_creator/actions/clear_all_reactions.dart';
import 'package:bot_creator/actions/ban_user.dart';
import 'package:bot_creator/actions/unban_user.dart';
import 'package:bot_creator/actions/kick_user.dart';
import 'package:bot_creator/actions/mute_user.dart';
import 'package:bot_creator/actions/unmute_user.dart';
import 'package:bot_creator/actions/pin_message.dart';
import 'package:bot_creator/actions/update_automod.dart';
import 'package:bot_creator/actions/update_guild.dart';
import 'package:bot_creator/actions/list_members.dart';
import 'package:bot_creator/actions/get_member.dart';
import 'package:bot_creator/actions/send_component_v2.dart';
import 'package:bot_creator/actions/edit_component_v2.dart';
import 'package:bot_creator/actions/send_webhook.dart';
import 'package:bot_creator/actions/edit_webhook.dart';
import 'package:bot_creator/actions/delete_webhook.dart';
import 'package:bot_creator/actions/list_webhooks.dart';
import 'package:bot_creator/actions/get_webhook.dart';
import 'package:bot_creator/utils/database.dart';
import 'package:http/http.dart' as http;
import 'package:nyxx/nyxx.dart';
import 'dart:convert';
import '../types/action.dart';
import 'handler_utils.dart';

Snowflake? _toSnowflake(dynamic value) {
  if (value == null) {
    return null;
  }

  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    return null;
  }

  return Snowflake(parsed);
}

dynamic _extractByJsonPath(dynamic data, String rawPath) {
  var path = rawPath.trim();
  if (path.isEmpty) {
    return null;
  }

  if (path.startsWith(r'$.')) {
    path = path.substring(2);
  } else if (path.startsWith(r'$')) {
    path = path.substring(1);
  }

  if (path.isEmpty) {
    return data;
  }

  final segments = <Object>[];
  final token = StringBuffer();

  void flushToken() {
    if (token.isNotEmpty) {
      segments.add(token.toString());
      token.clear();
    }
  }

  for (var i = 0; i < path.length; i++) {
    final char = path[i];
    if (char == '.') {
      flushToken();
      continue;
    }

    if (char == '[') {
      flushToken();
      final closing = path.indexOf(']', i + 1);
      if (closing == -1) {
        return null;
      }
      final indexText = path.substring(i + 1, closing).trim();
      final index = int.tryParse(indexText);
      if (index == null) {
        return null;
      }
      segments.add(index);
      i = closing;
      continue;
    }

    token.write(char);
  }
  flushToken();

  dynamic current = data;
  for (final segment in segments) {
    if (segment is String) {
      if (segment.isEmpty) {
        continue;
      }
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
      continue;
    }

    if (segment is int) {
      if (current is List && segment >= 0 && segment < current.length) {
        current = current[segment];
      } else {
        return null;
      }
    }
  }

  return current;
}

// Helper functions for common action patterns

Future<Map<String, String>> _executeUserAction(
  Future<Map<String, String>> Function() action, {
  required Snowflake? guildId,
  String actionName = 'User action',
}) async {
  if (guildId == null) {
    throw Exception('$actionName requires a guild context');
  }
  return action();
}

Future<Map<String, String>> handleActions(
  NyxxGateway client,
  ApplicationCommandInteraction interaction, {
  required List<Action> actions,
  required AppManager manager,
  required String botId,
  required Map<String, String> variables,
  required String Function(String input) resolveTemplate,
  Set<String>? workflowStack,
}) async {
  final results = <String, String>{};
  final fallbackChannelId = interaction.channel?.id;
  final guildId = interaction.guildId;
  final activeWorkflowStack = workflowStack ?? <String>{};

  String resolveValue(String value) => resolveTemplate(value);

  String normalizeMethod(dynamic rawMethod) {
    final method =
        resolveValue(rawMethod?.toString() ?? 'GET').trim().toUpperCase();
    const supported = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD'};
    if (!supported.contains(method)) {
      return 'GET';
    }
    return method;
  }

  bool supportsBody(String method) {
    return method != 'GET' && method != 'HEAD';
  }

  dynamic resolveJsonLike(dynamic value) {
    if (value is String) {
      return resolveValue(value);
    }
    if (value is List) {
      return value.map(resolveJsonLike).toList();
    }
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map((entry) {
          return MapEntry(entry.key.toString(), resolveJsonLike(entry.value));
        }),
      );
    }
    return value;
  }

  for (var i = 0; i < actions.length; i++) {
    final action = actions[i];
    if (!action.enabled) {
      continue;
    }

    final resultKey = action.key ?? 'action_$i';

    try {
      switch (action.type) {
        case BotCreatorActionType.deleteMessages:
          final channelId =
              _toSnowflake(action.payload['channelId']) ?? fallbackChannelId;
          if (channelId == null) {
            throw Exception('Missing or invalid channelId for deleteMessages');
          }

          final result = await deleteMessage(
            client,
            channelId,
            count: action.payload['messageCount'] ?? 0,
            onlyThisUserID: action.payload['onlyUserId']?.toString() ?? '',
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['count'] ?? '0';
          break;
        case BotCreatorActionType.createChannel:
          if (guildId == null) {
            throw Exception('This action requires a guild context');
          }

          final typeRaw = (action.payload['type'] ?? 'text').toString();
          final channelType =
              typeRaw == 'voice'
                  ? ChannelType.guildVoice
                  : ChannelType.guildText;
          final result = await createChannel(
            client,
            (action.payload['name'] ?? '').toString(),
            guildId: guildId,
            type: channelType,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['channelId'] ?? '';
          break;
        case BotCreatorActionType.updateChannel:
          final result = await updateChannelAction(
            client,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['channelId'] ?? '';
          break;
        case BotCreatorActionType.removeChannel:
          final channelId = _toSnowflake(action.payload['channelId']);
          if (channelId == null) {
            throw Exception('Missing or invalid channelId for removeChannel');
          }

          final result = await removeChannel(client, channelId);
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['channelId'] ?? '';
          break;
        case BotCreatorActionType.sendMessage:
          final channelId =
              _toSnowflake(action.payload['channelId']) ?? fallbackChannelId;
          if (channelId == null) {
            throw Exception('Missing or invalid channelId for sendMessage');
          }

          final content = resolveValue(
            (action.payload['content'] ?? '').toString(),
          );
          if (content.trim().isEmpty) {
            throw Exception('content is required for sendMessage');
          }

          final result = await sendMessageToChannel(
            client,
            channelId,
            content: content,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.editMessage:
          final content = resolveValue(
            (action.payload['content'] ?? '').toString(),
          );
          final result = await editMessageAction(
            client,
            payload: action.payload,
            fallbackChannelId: fallbackChannelId,
            content: content,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.addReaction:
          final result = await addReactionAction(
            client,
            payload: action.payload,
            fallbackChannelId: fallbackChannelId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['status'] ?? 'OK';
          break;
        case BotCreatorActionType.removeReaction:
          final result = await removeReactionAction(
            client,
            payload: action.payload,
            fallbackChannelId: fallbackChannelId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['status'] ?? 'OK';
          break;
        case BotCreatorActionType.clearAllReactions:
          final result = await clearAllReactionsAction(
            client,
            payload: action.payload,
            fallbackChannelId: fallbackChannelId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['status'] ?? 'OK';
          break;
        case BotCreatorActionType.banUser:
        case BotCreatorActionType.unbanUser:
        case BotCreatorActionType.kickUser:
        case BotCreatorActionType.muteUser:
        case BotCreatorActionType.unmuteUser:
          final result = await _executeUserAction(() async {
            return switch (action.type) {
              BotCreatorActionType.banUser => banUserAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              BotCreatorActionType.unbanUser => unbanUserAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              BotCreatorActionType.kickUser => kickUserAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              BotCreatorActionType.muteUser => muteUserAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              BotCreatorActionType.unmuteUser => unmuteUserAction(
                client,
                guildId: guildId,
                payload: action.payload,
              ),
              _ => throw Exception('Unexpected action type'),
            };
          }, guildId: guildId);
          if (result.hasError) {
            throw Exception(result.error);
          }
          results[resultKey] = result.getOrEmpty('userId');
          break;
        case BotCreatorActionType.pinMessage:
          final result = await pinMessageAction(
            client,
            payload: action.payload,
            fallbackChannelId: fallbackChannelId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.updateAutoMod:
          final result = await updateAutoModAction(
            client,
            guildId: guildId,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['status'] ?? 'OK';
          break;
        case BotCreatorActionType.updateGuild:
          final result = await updateGuildAction(
            client,
            guildId: guildId,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['guildId'] ?? '';
          break;
        case BotCreatorActionType.listMembers:
          final result = await listMembersAction(
            client,
            guildId: guildId,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['members'] ?? '[]';
          break;
        case BotCreatorActionType.getMember:
          final result = await getMemberAction(
            client,
            guildId: guildId,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['member'] ?? '';
          break;
        case BotCreatorActionType.sendComponentV2:
          final result = await sendComponentV2Action(
            client,
            payload: action.payload,
            fallbackChannelId: fallbackChannelId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.editComponentV2:
          final result = await editComponentV2Action(
            client,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.sendWebhook:
        case BotCreatorActionType.editWebhook:
        case BotCreatorActionType.deleteWebhook:
          final result = await switch (action.type) {
            BotCreatorActionType.sendWebhook => sendWebhookAction(
              client,
              payload: action.payload,
            ),
            BotCreatorActionType.editWebhook => editWebhookAction(
              client,
              payload: action.payload,
            ),
            BotCreatorActionType.deleteWebhook => deleteWebhookAction(
              client,
              payload: action.payload,
            ),
            _ => throw Exception('Unexpected action type'),
          };
          if (result.hasError) {
            throw Exception(result.error);
          }
          results[resultKey] = result.getOrEmpty('webhookId');
          break;
        case BotCreatorActionType.listWebhooks:
          final result = await listWebhooksAction(
            client,
            payload: action.payload,
            fallbackChannelId: fallbackChannelId,
            fallbackGuildId: guildId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['webhooks'] ?? '[]';
          break;
        case BotCreatorActionType.getWebhook:
          final result = await getWebhookAction(
            client,
            payload: action.payload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['webhook'] ?? '';
          break;
        case BotCreatorActionType.makeList:
          final result = formatList(
            action.payload['list'] ?? [],
            action.payload['format']?.toString() ?? '',
          );
          results[resultKey] = result.toString();
          break;
        case BotCreatorActionType.httpRequest:
          final resolvedUrl =
              resolveValue((action.payload['url'] ?? '').toString()).trim();
          if (resolvedUrl.isEmpty) {
            throw Exception('url is required for httpRequest');
          }

          final method = normalizeMethod(action.payload['method']);
          final bodyMode =
              resolveValue(
                (action.payload['bodyMode'] ?? 'json').toString(),
              ).toLowerCase();

          final headersRaw = Map<String, dynamic>.from(
            (action.payload['headers'] as Map?)?.cast<String, dynamic>() ??
                const {},
          );
          final headers = <String, String>{};
          for (final entry in headersRaw.entries) {
            final key = resolveValue(entry.key).trim();
            if (key.isEmpty) {
              continue;
            }
            headers[key] = resolveValue(entry.value?.toString() ?? '');
          }

          Object? requestBody;
          if (supportsBody(method)) {
            if (bodyMode == 'text') {
              requestBody = resolveValue(
                (action.payload['bodyText'] ?? '').toString(),
              );
            } else {
              final bodyJsonRaw =
                  (action.payload['bodyJson'] is Map)
                      ? Map<String, dynamic>.from(
                        (action.payload['bodyJson'] as Map)
                            .cast<String, dynamic>(),
                      )
                      : <String, dynamic>{};
              final resolvedJson = resolveJsonLike(bodyJsonRaw);
              requestBody = jsonEncode(resolvedJson);
              headers.putIfAbsent('Content-Type', () => 'application/json');
            }
          }

          final uri = Uri.tryParse(resolvedUrl);
          if (uri == null) {
            throw Exception('Invalid URL for httpRequest: $resolvedUrl');
          }

          final request = http.Request(method, uri);
          request.headers.addAll(headers);
          if (requestBody != null && requestBody.toString().isNotEmpty) {
            request.body = requestBody.toString();
          }

          final streamed = await http.Client().send(request);
          final responseBody = await streamed.stream.bytesToString();
          final status = streamed.statusCode;

          results[resultKey] = 'HTTP $status';
          variables['action.$resultKey.status'] = '$status';
          variables['action.$resultKey.body'] = responseBody;
          variables['$resultKey.status'] = '$status';
          variables['$resultKey.body'] = responseBody;

          final saveBodyTo =
              resolveValue(
                (action.payload['saveBodyToGlobalVar'] ?? '').toString(),
              ).trim();
          if (saveBodyTo.isNotEmpty) {
            await manager.setGlobalVariable(botId, saveBodyTo, responseBody);
          }

          final saveStatusTo =
              resolveValue(
                (action.payload['saveStatusToGlobalVar'] ?? '').toString(),
              ).trim();
          if (saveStatusTo.isNotEmpty) {
            await manager.setGlobalVariable(botId, saveStatusTo, '$status');
          }

          final extractPath =
              resolveValue(
                (action.payload['extractJsonPath'] ?? '').toString(),
              ).trim();
          if (extractPath.isNotEmpty) {
            dynamic decoded;
            try {
              decoded = jsonDecode(responseBody);
            } catch (_) {
              decoded = null;
            }

            if (decoded != null) {
              final extracted = _extractByJsonPath(decoded, extractPath);
              if (extracted != null) {
                final extractedAsString =
                    extracted is String
                        ? extracted
                        : (extracted is num || extracted is bool)
                        ? extracted.toString()
                        : jsonEncode(extracted);
                variables['action.$resultKey.jsonPath'] = extractedAsString;
                variables['$resultKey.jsonPath'] = extractedAsString;

                final saveExtractTo =
                    resolveValue(
                      (action.payload['saveJsonPathToGlobalVar'] ?? '')
                          .toString(),
                    ).trim();
                if (saveExtractTo.isNotEmpty) {
                  await manager.setGlobalVariable(
                    botId,
                    saveExtractTo,
                    extractedAsString,
                  );
                }
              }
            }
          }
          break;
        case BotCreatorActionType.setGlobalVariable:
          final key =
              resolveValue((action.payload['key'] ?? '').toString()).trim();
          if (key.isEmpty) {
            throw Exception('key is required for setGlobalVariable');
          }
          final value = resolveValue(
            (action.payload['value'] ?? '').toString(),
          );
          await manager.setGlobalVariable(botId, key, value);
          variables['global.$key'] = value;
          results[resultKey] = 'OK';
          break;
        case BotCreatorActionType.getGlobalVariable:
          final key =
              resolveValue((action.payload['key'] ?? '').toString()).trim();
          if (key.isEmpty) {
            throw Exception('key is required for getGlobalVariable');
          }
          final value = await manager.getGlobalVariable(botId, key) ?? '';
          final storeAs =
              resolveValue(
                (action.payload['storeAs'] ?? 'global.$key').toString(),
              ).trim();
          if (storeAs.isNotEmpty) {
            variables[storeAs] = value;
          }
          variables['global.$key'] = value;
          results[resultKey] = value;
          break;
        case BotCreatorActionType.removeGlobalVariable:
          final key =
              resolveValue((action.payload['key'] ?? '').toString()).trim();
          if (key.isEmpty) {
            throw Exception('key is required for removeGlobalVariable');
          }
          await manager.removeGlobalVariable(botId, key);
          variables.remove('global.$key');
          results[resultKey] = 'REMOVED';
          break;
        case BotCreatorActionType.listGlobalVariables:
          final globals = await manager.getGlobalVariables(botId);
          final asJson = jsonEncode(globals);
          final storeAs =
              resolveValue(
                (action.payload['storeAs'] ?? 'global.list').toString(),
              ).trim();
          if (storeAs.isNotEmpty) {
            variables[storeAs] = asJson;
          }
          results[resultKey] = asJson;
          break;
        case BotCreatorActionType.runWorkflow:
          final workflowName =
              resolveValue(
                (action.payload['workflowName'] ?? '').toString(),
              ).trim();
          if (workflowName.isEmpty) {
            throw Exception('workflowName is required for runWorkflow');
          }
          final lowered = workflowName.toLowerCase();
          if (activeWorkflowStack.contains(lowered)) {
            throw Exception('Workflow recursion detected for "$workflowName"');
          }

          final workflow = await manager.getWorkflowByName(botId, workflowName);
          if (workflow == null) {
            throw Exception('Workflow not found: $workflowName');
          }

          final workflowActions = List<Action>.from(
            ((workflow['actions'] as List?) ?? const <dynamic>[])
                .whereType<Map>()
                .map(
                  (json) => Action.fromJson(Map<String, dynamic>.from(json)),
                ),
          );

          activeWorkflowStack.add(lowered);
          final workflowResults = await handleActions(
            client,
            interaction,
            actions: workflowActions,
            manager: manager,
            botId: botId,
            variables: variables,
            resolveTemplate: resolveTemplate,
            workflowStack: activeWorkflowStack,
          );
          activeWorkflowStack.remove(lowered);

          for (final entry in workflowResults.entries) {
            results['$resultKey.${entry.key}'] = entry.value;
          }
          results[resultKey] = 'WORKFLOW_OK';
          break;
      }
    } catch (e) {
      results[resultKey] = 'Error: $e';
      if (action.onErrorMode == ActionOnErrorMode.stop) {
        break;
      }
    }
  }
  return results;
}
