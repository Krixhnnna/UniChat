import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _fcmToken;
  bool _isInitialized = false;

  // Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permission for iOS
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      } else {
        print('User declined or has not accepted permission');
      }

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      print('FCM Token: $_fcmToken');

      // Save FCM token to user's document
      if (_fcmToken != null && _auth.currentUser != null) {
        await _saveFcmToken(_fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFcmToken(newToken);
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      _isInitialized = true;
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  // Save FCM token to user's document
  Future<void> _saveFcmToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM token saved successfully');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      
      // Show a simple in-app notification or snackbar
      // For now, just print the notification
      print('Notification: ${message.notification!.title} - ${message.notification!.body}');
    }
  }

  // Handle notification taps
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    
    // Handle navigation based on notification type
    final type = message.data['type'];
    if (type == 'chat_message') {
      // Navigate to chat screen
      print('Navigate to chat: ${message.data['chatId']}');
    }
  }

  // Send notification to a specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken == null) {
        print('User has no FCM token');
        return;
      }

      // Send notification via Cloud Function
      await _sendNotificationViaCloudFunction(
        fcmToken: fcmToken,
        title: title,
        body: body,
        data: data,
      );

      print('Notification sent successfully');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send notification via Cloud Function
  Future<void> _sendNotificationViaCloudFunction({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // This would typically call your Cloud Function
      // For now, we'll just print the notification details
      print('Sending notification to $fcmToken:');
      print('Title: $title');
      print('Body: $body');
      print('Data: $data');
      
      // In a real implementation, you would call your Cloud Function here
      // For example:
      // final response = await http.post(
      //   Uri.parse('your-cloud-function-url'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({
      //     'token': fcmToken,
      //     'title': title,
      //     'body': body,
      //     'data': data,
      //   }),
      // );
    } catch (e) {
      print('Error sending notification via Cloud Function: $e');
    }
  }

  // Get FCM token
  String? get fcmToken => _fcmToken;

  // Check if initialized
  bool get isInitialized => _isInitialized;
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');
  
  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification}');
  }
}
