/**
/// LifeDrop Cloud Functions (Firebase v1 Syntax)
/// Handles automated background logic: emergency broadcasts and account status alerts.
**/

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

// Initialize admin once at the very top to allow database and messaging access.
admin.initializeApp();

// ============================================================================
// FUNCTION 1: Urgent Blood Alerts
// Triggered when a new document is added to 'blood_requests' collection.
// ============================================================================
exports.sendUrgentBloodAlert = functions.region('europe-west1').firestore
    .document('blood_requests/{requestId}')
    .onCreate(async (snap, context) => {

        const requestData = snap.data();

        // Security check: Only broadcast if the request is marked as high-priority.
        if (requestData.urgency !== "Critical" && requestData.urgency !== "High") {
            console.log("Not an urgent request. No alert sent.");
            return null;
        }

        const requestedBloodType = requestData.bloodType;
        const hospitalName = requestData.hospitalName || "a local hospital";

        // Medical logic: define which blood groups can donate to the requested type.
        const compatibilityMap = {
            "A+": ["A+", "A-", "O+", "O-"], //requested blood type and all compatible donors
            "A-": ["A-", "O-"],
            "B+": ["B+", "B-", "O+", "O-"],
            "B-": ["B-", "O-"],
            "AB+": ["AB+", "AB-", "A+", "A-", "B+", "B-", "O+", "O-"],
            "AB-": ["AB-", "A-", "B-", "O-"],
            "O+": ["O+", "O-"],
            "O-": ["O-"]
        };

        const compatibleDonors = compatibilityMap[requestedBloodType];

        if (!compatibleDonors) {
            console.log("Unknown blood type:", requestedBloodType);
            return null;
        }

        // Query: Find all users in the 'users' collection who match the medical compatibility.
        const usersSnapshot = await admin.firestore().collection("users")
            .where("bloodType", "in", compatibleDonors)
            .get();

        if (usersSnapshot.empty) {
            console.log("No compatible donors found.");
            return null;
        }

        const tokens = [];
        const validRoles = ["Donor", "Both"];

        // Iterate through matching users to collect FCM tokens and create internal notification logs.
        usersSnapshot.forEach(doc => {
            const userData = doc.data();

            // Exclude the user who actually posted the request.
            if (validRoles.includes(userData.role) && doc.id !== requestData.requesterId) {
                if (userData.fcmToken) {
                    tokens.push(userData.fcmToken);
                }

                // Create a record in the 'notifications' collection for the user's history screen.
                admin.firestore().collection("notifications").add({
                    userId: doc.id,
                    title: "Urgent Blood Needed!",
                    body: `Immediate need for ${requestedBloodType} blood at ${hospitalName}. Tap to help!`,
                    type: "emergency",
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    isRead: false,
                    relatedId: context.params.requestId
                });
            }
        });

        if (tokens.length === 0) {
            console.log("Found users, but none matched the roles or had push tokens.");
            return null;
        }

        // FCM Message Payload: Explicitly targeting high-priority background delivery.
        const message = {
            notification: {
                title: "Urgent Blood Needed!",
                body: `Immediate need for ${requestedBloodType} blood at ${hospitalName}. Tap to help!`,
            },
            android: {
                notification: {
                    channelId: "emergency_channel", // Defined in main.dart; ensures sound and pop-up.
                    priority: "high",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                }
            },
            tokens: tokens,
        };

        try {
            // Broadcast the emergency alert to all matching tokens.
            const response = await admin.messaging().sendEachForMulticast(message);
            console.log(`Successfully sent ${response.successCount} alerts!`);
            return response;
        } catch (error) {
            console.error("Error sending emergency alert:", error);
            return null;
        }
    });


// ============================================================================
// FUNCTION 2: Admin Document Verification Status
// Triggered when an admin updates a user's verificationStatus field.
// ============================================================================
exports.notifyVerificationStatus = functions.region('europe-west1').firestore
    .document('users/{userId}')
    .onUpdate(async (change, context) => {

        const newValue = change.after.data();
        const previousValue = change.before.data();

        // Only proceed if the verification status actually changed.
        if (newValue.verificationStatus === previousValue.verificationStatus) {
            return null;
        }

        const status = newValue.verificationStatus;
        const fcmToken = newValue.fcmToken;

        if (!fcmToken) {
            console.log("No FCM token found for user:", context.params.userId);
            return null;
        }

        let payload = {
            notification: {
                title: "",
                body: ""
            },
            // Ensuring the notification uses the correct high-priority channel on Android.
            android: {
                notification: {
                    channelId: "verification_channel",
                    priority: "high",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK"
                }
            }
        };

        // Dynamic content based on approval or rejection.
        if (status === 'approved') {
            payload.notification.title = "Account Verified! ✅";
            payload.notification.body = "Your documents have been approved. You can now donate blood.";
        } else if (status === 'rejected') {
            payload.notification.title = "Verification Failed ❌";
            payload.notification.body = "There was an issue with your documents. Please review and re-upload.";
        } else {
            return null;
        }

        try {
            // Send the personalized status alert directly to the user's device.
            const response = await admin.messaging().sendToDevice(fcmToken, payload);
            console.log("Verification Notification sent successfully:", response);
            return response;
        } catch (error) {
            console.error("Error sending verification notification:", error);
            return null;
        }
    });
