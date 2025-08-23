# 🔔 Push Notifications Setup Guide

## 📱 Current Status
✅ **Client-side FCM setup** - Complete  
✅ **Cloud Functions code** - Complete  
✅ **Notification navigation** - Complete  
⚠️ **Cloud Functions deployment** - Requires IAM permissions

## 🚀 To Enable Full Push Notifications

### Step 1: Deploy Cloud Functions
You need to run these commands as a **Firebase project owner** or have the required IAM permissions:

```bash
# Make sure you're logged in as project owner
firebase login

# Deploy the functions
firebase deploy --only functions
```

If you get IAM errors, run these commands as project owner:
```bash
gcloud projects add-iam-policy-binding collegecrush-eec15 --member=serviceAccount:service-546467456849@gcp-sa-pubsub.iam.gserviceaccount.com --role=roles/iam.serviceAccountTokenCreator

gcloud projects add-iam-policy-binding collegecrush-eec15 --member=serviceAccount:546467456849-compute@developer.gserviceaccount.com --role=roles/run.invoker

gcloud projects add-iam-policy-binding collegecrush-eec15 --member=serviceAccount:546467456849-compute@developer.gserviceaccount.com --role=roles/eventarc.eventReceiver
```

### Step 2: Test Notifications
Once deployed, test by:
1. **Send a message** from one user to another
2. **Check Firebase Functions logs**: `firebase functions:log`
3. **Verify notification appears** on recipient's device (even when app is closed)

## 🔧 What's Already Working

### ✅ FCM Token Management
- Tokens are automatically generated and saved to user documents
- Tokens refresh automatically when needed
- Permission requests handled for iOS/Android

### ✅ Message Structure
- Messages are stored in `/chats/{chatId}/messages/{messageId}`
- Cloud Functions trigger on new message creation
- Proper error handling and logging

### ✅ Notification Types
- **Chat Messages**: Shows sender name and message preview
- **Friend Requests**: Shows "New Request" with sender name
- **Navigation**: Automatically opens relevant screen when tapped

### ✅ Smart Features
- **Message Truncation**: Long messages show "..." after 50 chars
- **Media Messages**: Shows "📷 Photo" or "🎤 Voice message"
- **Unread Counts**: Automatically incremented when notifications sent
- **Duplicate Prevention**: Only sends to users with FCM tokens

## 📊 Cloud Functions Overview

### `sendMessageNotification`
- **Trigger**: New document in `/chats/{chatId}/messages/{messageId}`
- **Action**: Sends push notification to message recipient
- **Features**: Smart content handling, unread count updates

### `sendRequestNotification`  
- **Trigger**: New document in `/requests/{requestId}`
- **Action**: Sends push notification for friend requests
- **Features**: Sender name lookup, proper navigation data

## 🎯 Expected Behavior After Deployment

### 📱 App Closed
- User receives push notification instantly
- Notification shows sender name and message preview
- Tapping opens app and navigates to chat

### 📱 App Backgrounded
- User receives push notification
- Notification appears in notification center
- Tapping brings app to foreground and navigates

### 📱 App Open
- Real-time message delivery (existing functionality)
- No duplicate notifications shown

## 🔍 Troubleshooting

### No Notifications Received
1. Check Firebase Functions logs: `firebase functions:log`
2. Verify FCM token exists in user document
3. Ensure notifications are enabled in device settings
4. Check if Cloud Functions deployed successfully

### Notifications Not Opening Chat
1. Verify notification data includes correct `chatId` and `senderId`
2. Check console logs for navigation errors
3. Ensure user document exists for sender

### Functions Not Triggering
1. Verify Firestore security rules allow message creation
2. Check Functions logs for deployment errors
3. Ensure required APIs are enabled in Google Cloud Console

## 📝 Next Steps
1. **Deploy functions** with proper permissions
2. **Test end-to-end** notification flow
3. **Monitor logs** for any issues
4. **Add notification preferences** (optional future enhancement)

---
*Once deployed, users will receive instant push notifications even when the app is completely closed! 🎉*
