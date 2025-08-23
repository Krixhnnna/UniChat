#!/bin/bash

# Script to deploy Firestore rules and indexes for optimal performance

echo "🚀 Deploying Firestore configuration for optimal performance..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged in to Firebase. Please login first:"
    echo "firebase login"
    exit 1
fi

echo "📋 Current project:"
firebase use

echo ""
echo "🔐 Deploying Firestore security rules..."
firebase deploy --only firestore:rules

echo ""
echo "🔍 Deploying Firestore indexes..."
firebase deploy --only firestore:indexes

echo ""
echo "✅ Firestore configuration deployed successfully!"
echo ""
echo "📊 Recommended indexes for optimal performance:"
echo "  - users.isOnline + users.lastActive (for online status queries)"
echo "  - users.college + users.isOnline (for college-based filtering)"
echo "  - users.displayNameLower (for search functionality)"
echo "  - chats.participants + chats.lastMessageTime (for chat list)"
echo "  - messages.timestamp (for message ordering)"
echo "  - messages.senderId + messages.isRead (for unread message queries)"
echo ""
echo "⚡ Performance tips:"
echo "  - These indexes will significantly improve query performance"
echo "  - Monitor index usage in Firebase Console"
echo "  - Consider enabling TTL for old messages if storage becomes an issue"
echo "  - Use composite indexes for complex queries"
echo ""
echo "🔧 Next steps:"
echo "  1. Monitor query performance in Firebase Console"
echo "  2. Add more indexes based on app usage patterns"
echo "  3. Consider setting up Firebase Performance Monitoring"
