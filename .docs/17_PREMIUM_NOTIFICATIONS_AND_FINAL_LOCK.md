# 17_PREMIUM_NOTIFICATIONS_AND_FINAL_LOCK.md: MINDFUL NOTIFICATION SUITE & SYSTEM LOCK
# Project: UR-Heart (Mindful Dating Sanctuary)
# Visual Experience: Editorial Aesthetic, Bespoke Micro-Haptics & Discreet Privacy
# Scope: FCM Data-Only Payloads, Local Heads-Up Styling & Catch-All Architectural Lock

---

## 1. MINDFUL NOTIFICATION PHILOSOPHY (ZERO JUNK, ZERO NOISE)

Standard dating apps spam users with gamified clickbait notifications (*"Someone is looking at you! 🔥"*, *"Don't let your match wait!"*). This breaks user trust and destroys mindful intent. 

UR-Heart replaces noisy alerts with **Bespoke Editorial Resonance Alerts**:
1. **Poetic, Unhurried Copy**: Notifications read like a private, thoughtful note rather than a system ping.
2. **Discreet Mode Privacy Masking (Screen 13)**: Jab user `discreet_mode = true` enable karta hai, to lock screen ya heads-up banner par sender ka naam, photo ya message snippet 100% mask rehta hai[cite: 14, 27].
3. **Gentle Haptic Micro-Pulse**: Default harsh Android vibration buzzers ke bajaye UR-Heart custom dual micro-pulses (`[0, 60, 100, 60] ms`) fire karta hai, jo ek soft heartbeat feel deliver karta hai.
4. **Night Slumber Silence**: 11:00 PM se 7:00 AM ke beech koi bhi audible chime fire nahi hoga agar user ne Screen 13 par *Night Sanctuary Slumber* toggle kiya hua hai[cite: 14, 27].

---

## 2. NOTIFICATION CHANNEL TAXONOMY & ANDROID SYSTEM MATRIX

Android 8.0+ (API 26+) ke liye notifications ko 4 isolated notification channels mein categorize kiya gaya hai:

| Channel ID | Channel Name | Importance | Sound & Chimes | Lock Screen Visibility | User Overridable |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `sanctuary_resonances` | Sacred Resonances | `IMPORTANCE_HIGH` | `sanctuary_bell.ogg` | Private (Masked in Discreet) | Yes (In Settings) |
| `sanctuary_dialogues` | Encrypted Dialogues | `IMPORTANCE_HIGH` | `soft_chime.ogg` | Private (Masked in Discreet) | Yes (In Settings) |
| `sanctuary_harvest` | Slumber & Harvest | `IMPORTANCE_LOW` | Silent / None | Public (Morning Greeting) | Yes (In Settings) |
| `sanctuary_statutory` | Governance & Security | `IMPORTANCE_MAX` | System Default | Public (Account / Legal) | No (Statutory Mandate) |

---

## 3. EDITORIAL COPY MATRIX (PREMIUM SANCTUARY DICTIONARY)

FCM backend dispatcher strictly in editorial templates ka use karega:

### 3.1 Channel: `sanctuary_resonances` (New Likes & Matches)[cite: 8, 21]
* **Standard Copy (Discreet Mode OFF)**:
  * *Title*: `A New Resonance Has Stirred`
  * *Body*: `"{sender_name}" felt an authentic alignment with your sanctuary presence.`
* **Discreet Mode ON (Masked Privacy)**[cite: 14, 27]:
  * *Title*: `UR-Heart Sanctuary`[cite: 2]
  * *Body*: `A quiet soul has resonated with your presence.`

### 3.2 Channel: `sanctuary_dialogues` (Incoming 1:1 Messages)[cite: 9, 22]
* **Standard Copy (Discreet Mode OFF)**:
  * *Title*: `{sender_name}`
  * *Body*: `Sent a thoughtful passage in your private dialogue.`
* **Discreet Mode ON (Masked Privacy)**[cite: 14, 27]:
  * *Title*: `UR-Heart Sanctuary`[cite: 2]
  * *Body*: `A new dialogue reflection awaits within your vault.`

### 3.3 Channel: `sanctuary_harvest` (Morning Slumber Notification)[cite: 11, 24]
* *Title*: `The Morning Light Enters`
* *Body*: `Your slumber has gathered quiet energy. Claim your mindful morning harvest (+20 Swipes).`

### 3.4 Feature: `whatsapp_reveal` (Enclave Reveal Unlocked)[cite: 1, 11, 24]
* *Title*: `Sacred Enclave Unlocked`
* *Body*: `Both souls have completed the 3-fold ritual. The WhatsApp bridge with {match_name} is now open for 24 hours.`[cite: 1, 11, 24]

---

## 4. DATA-ONLY FCM ARCHITECTURE (CUSTOM HEADS-UP RENDERER)

Agar FCM message standard `notification` payload ke sath bheja jaye, to Android OS background mein use default white system layout se render kar deta hai. Isse discreet mode override nahi ho pata aur visual customization break ho jati hai.

UR-Heart **100% Data-Only FCM Payloads** use karta hai:
* Server FCM payload mein `notification: {}` block include **nahi** karta.
* Server sirf `data: {}` dictionary send karta hai.
* Flutter client ka background worker payload intercept karta hai, local database se user ka `discreet_mode` check karta hai, aur `flutter_local_notifications` ke zariye rich, bespoke notification canvas build karta hai[cite: 14, 27].

### 4.1 Backend Python Notification Dispatcher (`app/services/notification_service.py`)

```python
import os
from typing import Optional, Dict
from firebase_admin import messaging
from app.models.domain.user import User

async def dispatch_mindful_notification(
    recipient: User,
    channel_id: str,
    event_type: str,
    raw_title: str,
    raw_body: str,
    deep_link_path: str,
    extra_metadata: Optional[Dict[str, str]] = None
) -> bool:
    """
    Dispatches a high-priority data-only FCM message.
    Strips raw PII if recipient has discreet_mode enabled.[cite: 14]
    """
    if not recipient.fcm_token:
        return False

    # Check Night Slumber Silence (11 PM - 7 AM local time)[cite: 14]
    if recipient.night_slumber and channel_id != "sanctuary_statutory":[cite: 14]
        # In night mode, harvest and standard notifications are suppressed or lowered
        pass

    # Build Privacy-Masked Data Payload
    payload_data = {
        "channel_id": channel_id,
        "event_type": event_type,
        "raw_title": raw_title,
        "raw_body": raw_body,
        "discreet_mode": "true" if recipient.discreet_mode else "false",[cite: 14]
        "deep_link": deep_link_path,
        "timestamp": str(recipient.updated_at.timestamp())
    }

    if extra_metadata:
        payload_data.update(extra_metadata)

    # DATA-ONLY MESSAGE (Ensures custom Flutter client-side local renderer)
    message = messaging.Message(
        data=payload_data,
        token=recipient.fcm_token,
        android=messaging.AndroidConfig(
            priority="high",
            ttl=86400  # 24 Hours TTL
        )
    )

    try:
        messaging.send(message)
        return True
    except Exception:
        return False
5. FLUTTER CLIENT NOTIFICATION RECEIVER & ENGINE
5.1 Android System Setup & Dependencies (pubspec.yaml)
YAML


dependencies:
  firebase_messaging: ^15.1.3
  flutter_local_notifications: ^17.2.2
5.2 Foreground & Background Listener (lib/core/notifications/notification_engine.dart)
Dart


import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background Data-only push interceptor
  await NotificationEngine.instance.displayBespokeNotification(message.data);
}

class NotificationEngine {
  static final NotificationEngine instance = NotificationEngine._internal();
  NotificationEngine._internal();

  final FlutterLocalNotificationsPlugin _localPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_sanctuary_crest');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Register Background & Foreground Listeners
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((message) {
      displayBespokeNotification(message.data);
    });
  }

  Future<void> displayBespokeNotification(Map<String, dynamic> data) async {
    final bool isDiscreet = data['discreet_mode'] == 'true';[cite: 14]
    final String channelId = data['channel_id'] ?? 'sanctuary_dialogues';
    final String deepLink = data['deep_link'] ?? '/feed';

    // Apply Editorial Privacy Masking
    String title = data['raw_title'] ?? 'UR-Heart';
    String body = data['raw_body'] ?? 'A quiet presence awaits.';

    if (isDiscreet) {
      title = 'UR-Heart Sanctuary';[cite: 2]
      body = 'A new dialogue reflection awaits within your vault.';
    }

    // Bespoke Heartbeat Haptic Pattern (60ms on, 100ms off, 60ms on)
    final Int64List heartbeatVibration = Int64List.fromList([0, 60, 100, 60]);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'sanctuary_resonances' ? 'Sacred Resonances' : 'Encrypted Dialogues',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF1B2923),        // Dark Sanctuary Accent[cite: 2, 11]
      ledColor: const Color(0xFFE27D60),      // Soft Coral Accent LED[cite: 2, 3]
      ledOnMs: 500,
      ledOffMs: 1000,
      vibrationPattern: heartbeatVibration,
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
      icon: '@drawable/ic_sanctuary_crest',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _localPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: deepLink,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      // Execute deep link navigation via Global Navigator Key
      // e.g. AppRouter.router.push(payload);
    }
  }
}
6. THE FINAL SYSTEM OMISSIONS LOCK (EDGE-CASE CATCH-ALL)
Development ke dauran unexpected runtime crashes aur memory leaks se bachne ke liye ye 6 architectural locks freeze kiye gaye hain:

6.1 Soft Keyboard & Viewport Overflow Shield
Chat Screen (Screen 9) aur Profile Setup (Screen 4) par soft keyboard open hone par BOTTOM OVERFLOWED BY X PIXELS error aata hai.   
PNG
+ 3

Rule: Sabhi input scaffolds par resizeToAvoidBottomInset: true hona mandatory hai.

Chat Screen par messages stream ReverseListView ke andar wrap hogi taaki keyboard show hote hi scroll anchor bottom par maintain rahe.

6.2 Dual BlurHash Image Transition
Feed Cards (Screen 5) aur Persona Grid (Screen 11) par network image load hone se pehle blank/black box dikhna strictly prohibited hai:   
PNG
+ 3

Client pehle lightweight BlurHash string render karega.   
PDF

Cloudflare R2 se WebP download complete hone par smooth 200ms cross-fade transition execute hoga.   
PDF

Dart


Widget buildSanctuaryImage(String imageUrl, String blurHash) {
  return Image.network(
    imageUrl,
    fit: BoxFit.cover,
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded || frame != null) return child;
      return BlurHash(hash: blurHash);
    },
  );
}
6.3 Deep Link Route Authentication Guard
Agar user notification tap karta hai (/chat-dialogue?match_id=...) lekin app logged out state mein hai ya session invalidate ho chuka hai:   
PNG
+ 1

Router seedhe Chat Screen load nahi karega (Security leak prevent karne ke liye).

Guard target route ko memory mein cache karega aur user ko Screen 2 (Age Gate & Auth) par redirect karega.   
PNG
+ 1

Authentication successful hone par target route par navigate karega.

6.4 App Lifecycle & WebSocket Reconnect Watcher
Jab app background se foreground mein aaye:

WidgetsBindingObserver.didChangeAppLifecycleState intercept karega.

Agar socket state disconnected hai, to immediate exponential backoff ke sath /ws/chat socket reconnect karega[cite: 1].

Backend par /api/v1/auth/session-sync fire karke installation UUID verify karega[cite: 1].

6.5 Network Offline Graceful Banner
Agar device offline ho jaye:

Screen crash nahi hogi.

Top bar par subtle, elegant terracotta banner render hoga: "Sanctuary resting offline. Reconnecting quietly..."

6.6 Strict Null-Assertion (!) Prohibition in Dart
Dart codebase mein ! operator use karna strictly banned hai.

Har nullable value ko ?? (fallback) ya if (value != null) pattern se handle kiya jayega.