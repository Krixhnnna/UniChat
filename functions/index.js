/**
 * Cloud Functions for Campus Crush Push Notifications
 */

const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin
initializeApp();

// Set global options for cost control
setGlobalOptions({ maxInstances: 10 });

/**
 * Sends push notification when a new message is created
 * Triggers on: /chats/{chatId}/messages/{messageId}
 */
exports.sendMessageNotification = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    try {
      const messageData = event.data.data();
      const chatId = event.params.chatId;
      const messageId = event.params.messageId;

      logger.info("New message created", { 
        chatId, 
        messageId, 
        senderId: messageData.senderId 
      });

      // Get chat document to find participants
      const chatDoc = await getFirestore()
        .collection("chats")
        .doc(chatId)
        .get();

      if (!chatDoc.exists) {
        logger.error("Chat document not found", { chatId });
        return;
      }

      const chatData = chatDoc.data();
      const participants = chatData.participants || [];
      
      // Find the recipient (not the sender)
      const recipientId = participants.find(id => id !== messageData.senderId);
      
      if (!recipientId) {
        logger.warn("No recipient found", { participants, senderId: messageData.senderId });
        return;
      }

      // Get recipient's user data and FCM token
      const recipientDoc = await getFirestore()
        .collection("users")
        .doc(recipientId)
        .get();

      if (!recipientDoc.exists) {
        logger.error("Recipient user not found", { recipientId });
        return;
      }

      const recipientData = recipientDoc.data();
      const fcmToken = recipientData.fcmToken;

      if (!fcmToken) {
        logger.warn("Recipient has no FCM token", { recipientId });
        return;
      }

      // Get sender's name and profile picture
      const senderDoc = await getFirestore()
        .collection("users")
        .doc(messageData.senderId)
        .get();

      const senderData = senderDoc.exists ? senderDoc.data() : {};
      const senderName = senderData.displayName || "Someone";
      const senderProfilePic = senderData.profilePhotos && senderData.profilePhotos.length > 0 
        ? senderData.profilePhotos[0] 
        : null;

      // Prepare notification content
      let notificationBody = messageData.content || "New message";
      
      // Handle different message types
      if (messageData.imageUrl) {
        notificationBody = "📷 Photo";
      } else if (messageData.audioUrl) {
        notificationBody = "🎤 Voice message";
      } else if (messageData.content && messageData.content.length > 50) {
        notificationBody = messageData.content.substring(0, 50) + "...";
      }

      // Create notification payload with profile picture
      const payload = {
        token: fcmToken,
        notification: {
          title: senderName,
          body: notificationBody,
        },
        data: {
          type: "chat_message",
          chatId: chatId,
          senderId: messageData.senderId,
          senderName: senderName,
          senderProfilePic: senderProfilePic || "",
          messageId: messageId,
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chat_messages",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            icon: "ic_notification",
            color: "#8B5CF6",
            // Add profile picture for Android rich notifications
            ...(senderProfilePic && {
              imageUrl: senderProfilePic,
              style: "bigPicture"
            })
          }
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              alert: {
                title: senderName,
                body: notificationBody
              },
              // Add profile picture URL for iOS
              ...(senderProfilePic && {
                "mutable-content": 1,
                "attachment-url": senderProfilePic
              })
            }
          }
        }
      };

      // Send the notification
      const response = await getMessaging().send(payload);
      
      logger.info("Push notification sent successfully", { 
        messageId: response,
        recipientId,
        senderName 
      });

      // Note: Unread count is already handled by the Flutter app in sendMessage()
      // No need to increment here to avoid double counting

    } catch (error) {
      logger.error("Error sending push notification", error);
    }
  }
);

// Removed updateUnreadCount function - unread counts are now handled entirely by the Flutter app
// to prevent double counting issues

/**
 * Sends push notification for friend requests
 * Triggers on: /requests/{requestId}
 */
exports.sendRequestNotification = onDocumentCreated(
  "requests/{requestId}",
  async (event) => {
    try {
      const requestData = event.data.data();
      const requestId = event.params.requestId;

      logger.info("New request created", { 
        requestId, 
        senderId: requestData.senderId,
        receiverId: requestData.receiverId 
      });

      // Get receiver's user data and FCM token
      const receiverDoc = await getFirestore()
        .collection("users")
        .doc(requestData.receiverId)
        .get();

      if (!receiverDoc.exists) {
        logger.error("Receiver user not found", { receiverId: requestData.receiverId });
        return;
      }

      const receiverData = receiverDoc.data();
      const fcmToken = receiverData.fcmToken;

      if (!fcmToken) {
        logger.warn("Receiver has no FCM token", { receiverId: requestData.receiverId });
        return;
      }

      // Get sender's name
      const senderDoc = await getFirestore()
        .collection("users")
        .doc(requestData.senderId)
        .get();

      const senderName = senderDoc.exists ? 
        (senderDoc.data().displayName || "Someone") : 
        "Someone";

      // Create notification payload
      const payload = {
        token: fcmToken,
        notification: {
          title: "New Request",
          body: `${senderName} sent you a friend request`,
        },
        data: {
          type: "friend_request",
          requestId: requestId,
          senderId: requestData.senderId,
          senderName: senderName,
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        android: {
          priority: "high",
          notification: {
            channelId: "friend_requests",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            icon: "ic_notification",
            color: "#8B5CF6"
          }
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              alert: {
                title: "New Request",
                body: `${senderName} sent you a friend request`
              }
            }
          }
        }
      };

      // Send the notification
      const response = await getMessaging().send(payload);
      
      logger.info("Friend request notification sent successfully", { 
        messageId: response,
        receiverId: requestData.receiverId,
        senderName 
      });

    } catch (error) {
      logger.error("Error sending friend request notification", error);
    }
  }
);
