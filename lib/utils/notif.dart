import 'dart:developer' as developer;

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cardia_kexa/main.dart';
import 'package:flutter/material.dart';
import 'package:nyxx/nyxx.dart' as discord;

class NotificationController {
  static ReceivedAction? initialAction;
  static const int websocketNotificationId = 100;

  ///  *********************************************
  ///     INITIALIZATIONS
  ///  *********************************************
  ///
  static Future<void> initializeLocalNotifications() async {
    await AwesomeNotifications().initialize(
      null, //'resource://drawable/res_app_icon',//
      [
        NotificationChannel(
          channelKey: 'alerts',
          channelName: 'Alerts',
          channelDescription: 'Notification tests as alerts',
          playSound: false,
          onlyAlertOnce: false,
          groupAlertBehavior: GroupAlertBehavior.Children,
          importance: NotificationImportance.High,
          defaultPrivacy: NotificationPrivacy.Private,
          defaultColor: Colors.deepPurple,
          ledColor: Colors.deepPurple,
        ),
        NotificationChannel(
          channelKey: 'websocket_channel',
          channelName: 'WebSocket Connection',
          channelDescription: 'Notifications for WebSocket connection status',
          playSound: false,
          onlyAlertOnce: true,
          importance: NotificationImportance.High,
          defaultPrivacy: NotificationPrivacy.Private,
          defaultColor: Colors.green,
          ledColor: Colors.green,
        ),
      ],
      debug: true,
    );

    // Get initial notification action is optional
    initialAction = await AwesomeNotifications().getInitialNotificationAction(
      removeFromActionEvents: false,
    );
  }

  ///  *********************************************
  ///     NOTIFICATION EVENTS LISTENER
  ///  *********************************************
  ///  Notifications events are only delivered after call this method
  static Future<void> startListeningNotificationEvents() async {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  // Cette méthode sera appelée lorsqu'une action est reçue
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    developer.log(
      'Notification action received: ${receivedAction.toString()}',
      name: 'NotificationController - Action Received',
    );
    if (receivedAction.buttonKeyPressed == 'STOP_WEBSOCKET') {
      // Arrêter la connexion WebSocket ici
      await cancelWebSocketNotification();
      // find the client in the list
      discord.NyxxGateway? client;
      for (var bot in gateways) {
        if (bot.user.id.toString() == receivedAction.payload?['id']) {
          client = bot;
          break;
        }
      }

      if (client != null) {
        gateways.remove(client);
        developer.log(
          'Client removed: ${client.user.id}',
          name: 'NotificationController - Client Removed',
        );
        client.close();
        developer.log(
          'WebSocket connection closed for client: ${client.user.id}',
          name: 'NotificationController - WebSocket Closed',
        );
      } else {
        developer.log(
          'Client not found in the list',
          name: 'NotificationController - Client Not Found',
        );
      }
      // Ici, vous pouvez ajouter le code pour arrêter votre connexion WebSocket
      // Par exemple: WebSocketService.instance.disconnect();
    } else {
      // Gérer d'autres actions de notification si nécessaire
      // Par exemple: print('Notification action received');
      await NotificationController.createWebSocketNotification(
        title: receivedAction.title ?? 'Default Title',
        body: receivedAction.body ?? 'Default Body',
        id: receivedAction.payload?['id'],
      );
    }
  }

  // Cette méthode sera appelée lorsqu'une notification est rejetée
  @pragma('vm:entry-point')
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    developer.log(
      'Notification dismissed: ${receivedAction.toString()}',
      name: 'NotificationController - Action Dismissed',
    );
    // Vous pouvez gérer la logique de rejet de notification ici
    // Par exemple: print('Notification dismissed');
  }

  // Créer une notification non-dismissible pour la connexion WebSocket
  static Future<void> createWebSocketNotification({
    required String title,
    required String body,
    discord.NyxxGateway? client,
    String? id,
  }) async {
    // Vérifier les permissions
    if (!await AwesomeNotifications().isNotificationAllowed()) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    // Vérifier à nouveau les permissions
    if (!await AwesomeNotifications().isNotificationAllowed()) {
      return;
    }
    if (client != null) {
      // Vérifier si le client est déjà dans la liste
      if (gateways.contains(client)) {
        return; // Le client est déjà dans la liste, ne pas ajouter à nouveau
      } else {
        // Si le client n'est pas dans la liste, l'ajouter
        gateways.add(client);
      }
    }
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: websocketNotificationId,
        channelKey: 'websocket_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        locked: true, // Rend la notification non-dismissible
        autoDismissible:
            false, // Empêche la notification de se fermer automatiquement
        displayOnBackground: true,
        displayOnForeground: true,
        payload: {'id': client?.user.id.toString() ?? id ?? 'unknown'},
        category:
            NotificationCategory
                .Service, // Catégorie pour les services en cours
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'STOP_WEBSOCKET',
          label: 'Arrêter',
          actionType: ActionType.Default,
          isDangerousOption: true,
        ),
      ],
    );
  }

  // Annuler la notification WebSocket
  static Future<void> cancelWebSocketNotification() async {
    await AwesomeNotifications().cancel(websocketNotificationId);
  }

  static Future<void> resetBadgeCounter() async {
    await AwesomeNotifications().resetGlobalBadge();
  }

  static Future<void> cancelNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}
