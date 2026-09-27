# 06_MEDIA_PIPELINE_FIREBASE_STORAGE.md: ZERO-CARD MEDIA ARCHITECTURE & STORAGE CONSERVATION
# Project: UR-Heart (Mindful Dating Sanctuary)
# Provider: Firebase Cloud Storage (Google Cloud Spark Free Tier — Zero Credit Card Required)
# Core Principle: 100% Direct Client-to-Bucket Routing (Zero Server Media Bandwidth)
# Security & Privacy: EXIF Geolocation Stripping, Deterministic Slot Overwrite & Ephemeral KYC Purge

---

## 1. STRATEGIC PIVOT: ZERO-CREDIT-CARD INFRASTRUCTURE

### 1.1 The International Card Barrier & The Spark Plan Solution
Cloudflare R2 international credit cards mangta hai jo RBI e-mandate aur Indian banking restrictions ke chalte 90% Indian developers ke debit/credit cards reject kar deta hai. 

UR-Heart **Firebase Cloud Storage (Google Cloud Spark Plan)** use karta hai:
1. **Zero Financial Friction**: Google account ke sath 100% free bina kisi debit/credit card ke instantly active hota hai.
2. **Unified Google Ecosystem**: Hamara Firebase Auth aur Firebase Cloud Messaging (FCM) already configured hai; same Firebase credentials aur single SDK (`firebase_storage`) se pure media lifecycle ka management hota hai.
3. **Pure Zero Server Overhead**: FastAPI backend server (Render 512MB RAM) par media ka single byte bhi pass nahi hota. Flutter client direct Google Storage bucket se interact karta hai.

---

## 2. THE STORAGE MATHEMATICS (5 GB FREE TIER AT SCALE)

Firebase Cloud Storage Spark Plan permanent free limits deta hai:
* **Storage Allocation**: 5 GB ($5,242,880 \text{ KB}$)
* **Daily Download Bandwidth**: 1 GB / day ($1,048,576 \text{ KB / day}$)
* **Daily Operations**: 20,000 Uploads (Class A), 50,000 Downloads (Class B)

### 2.1 Compression & Sizing Economics
* Raw phone camera photos: $3 \text{ MB} - 12 \text{ MB}$ (Ye database aur storage ko 2 din mein crash kar dega).
* **UR-Heart Client-Side WebP Standard**: Target size **~35 KB** (Max ceiling: 50 KB) at $800 \times 1066$ resolution (3:4 editorial portrait aspect ratio).
* Total Photos Accommodated:
  $$\text{Capacity} = \frac{5,242,880 \text{ KB}}{35 \text{ KB}} \approx \mathbf{1,49,796\text{ High-Resolution Photos Bilkul FREE!}}$$

### 2.2 Download Bandwidth Protection (Aggressive Client Disk Caching)
Daily 1 GB download bandwidth exceed na ho, iske liye Flutter client `cached_network_image` use karta hai:
* Har photo device ke internal disk cache mein **30 din** ke liye cache ho jati hai.
* Ek user discovery feed deck par jab same profiles ya matches dobara dekhta hai, to **0 KB network bandwidth** consume hoti hai; image local flash memory se instant render hoti hai.
* Net Bandwidth Consumption: 1 GB/day bandwidth se **30,000+ daily unique card views** bina kisi bill ke serve hote hain.

---

## 3. DETERMINISTIC MEDIA ARCHITECTURE & FOLDER TOPOLOGY

Storage bucket mein koi bhi random ya duplicate file upload nahi hoti. Har user ke paas strictly deterministic pathing hoti hai:

gs://ur-heart-sanctuary.appspot.com/
│
├── users/
│   └── {user_uuid}/
│       └── moments/
│           ├── slot_1.webp        # Primary Anchor Portrait (Used for Video KYC matching)
│           ├── slot_2.webp        # Candid Moment 2
│           ├── slot_3.webp        # Candid Moment 3
│           ├── slot_4.webp        # Candid Moment 4
│           └── slot_5.webp        # Candid Moment 5
│
└── kyc_ephemeral/
└── {user_uuid}/
└── kyc_video.mp4          # 3-Second Live Video (HARD-PURGED in < 60s post-verification)


### 3.1 The In-Place Overwrite Rule (Zero Storage Leakage)
Jab user Profile Editor (Screen 11) par slot 2 ki photo change karta hai, to nayi photo purani photo ko **in-place overwrite** karti hai (`slot_2.webp`). Isse:
* Storage bucket mein kabhi bhi koi "orphan file" ya discarded photo bachi nahi rehti.
* Database mein URL change karne ki zarurat nahi hoti; image ke aage sirf `?v=timestamp` cache-buster query append hoti hai.
* User account ka maximum static storage footprint: $5 \text{ slots} \times 35 \text{ KB} = \mathbf{175 \text{ KB max}}$.

---

## 4. THE 100% TEXT-ONLY CHAT MANDATE (MATHEMATICAL PROOF)

Standard dating apps (Tinder/Bumble/WhatsApp) users ko chat ke andar photos, voice notes, stickers, aur videos share karne dete hain:
* Ek average user chat mein 10 photos aur 5 voice notes share karta hai ($~25 \text{ MB}$ per active dialogue).
* 10,000 matches par chat media consumption = $\mathbf{250 \text{ GB}}$! (Firebase free tier 5 din mein block ho jayega aur thousands of dollars ka bill create hoga).
* Chat media server par illegal, explicit, ya non-consensual content ka liability threat paida karta hai.

### The Non-Negotiable Sanctuary Law:
1. **Zero Media in Dialogues**: Chat interface (Screen 9) mein koi attachment button, camera icon, image picker, ya voice recorder widget **codebase mein exist hi nahi karega**.
2. **Text-Only Storage Consumption**: 
   * Ek text message = ~100 bytes.
   * 1,000,000 text messages = sirf **~100 MB** (jise Supabase 30-day purge cron routine waise bhi clean karta rehta hai).
3. **Dignity & Privacy**: User ko visuals sirf verified profile deck par dikhte hain; dialogues purely mindful communication ke liye reserved hain.

---

## 5. CLIENT-SIDE MEDIA PIPELINE IMPLEMENTATION (FLUTTER)

### 5.1 Step 1: WebP Re-encoding & EXIF Stripping (`lib/core/media/media_compressor.dart`)

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:blurhash_dart/blurhash_dart.dart' as blurhash;
import 'package:image/image.dart' as img;

class CompressedMediaResult {
  final Uint8List webpBytes;
  final String blurHash;
  final int byteSize;

  CompressedMediaResult({
    required this.webpBytes,
    required this.blurHash,
    required this.byteSize,
  });
}

class MediaCompressor {
  /// Strips EXIF metadata, resizes to 800x1066, encodes to WebP (<50KB),
  /// and generates BlurHash placeholder.
  static Future<CompressedMediaResult?> processPhoto(File rawFile) async {
    try {
      // 1. Hardware-accelerated WebP re-encoding & EXIF metadata stripping
      final Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        rawFile.absolute.path,
        minWidth: 800,
        minHeight: 1066,
        quality: 78,
        format: CompressFormat.webp,
        keepExif: false, // MANDATORY: Strips GPS latitude/longitude and camera serial
      );

      if (compressedBytes == null) return null;

      // 2. Generate 32x32 thumbnail for instantaneous BlurHash computation
      final img.Image? decoded = img.decodeImage(compressedBytes);
      if (decoded == null) return null;

      final img.Image thumbnail = img.copyResize(decoded, width: 32, height: 32);
      final String hash = blurhash.BlurHash.encode(thumbnail, numCompX: 4, numCompY: 3).hash;

      return CompressedMediaResult(
        webpBytes: compressedBytes,
        blurHash: hash,
        byteSize: compressedBytes.lengthInBytes,
      );
    } catch (_) {
      return null;
    }
  }
}
5.2 Step 2: Direct Client Upload to Firebase Storage (lib/core/media/firebase_media_uploader.dart)
Dart


import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseMediaUploader {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Directly uploads compressed WebP to the deterministic user slot.
  /// Bypasses backend entirely.
  static Future<String?> uploadProfileSlot({
    required String userUuid,
    required int slotNumber,
    required Uint8List webpBytes,
  }) async {
    assert(slotNumber >= 1 && slotNumber <= 5, 'Slot must be between 1 and 5');

    final String path = 'users/$userUuid/moments/slot_$slotNumber.webp';
    final Reference ref = _storage.ref().child(path);

    final SettableMetadata metadata = SettableMetadata(
      contentType: 'image/webp',
      cacheControl: 'public, max-age=2592000', // 30 Days Client Cache
      customMetadata: {
        'uploaded_at': DateTime.now().toIso8601String(),
        'slot_id': slotNumber.toString(),
      },
    );

    try {
      final UploadTask uploadTask = ref.putData(webpBytes, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  /// Uploads ephemeral 3-second live KYC video.
  static Future<String?> uploadEphemeralKycVideo({
    required String userUuid,
    required Uint8List videoBytes,
  }) async {
    final String path = 'kyc_ephemeral/$userUuid/kyc_video.mp4';
    final Reference ref = _storage.ref().child(path);

    final SettableMetadata metadata = SettableMetadata(
      contentType: 'video/mp4',
      customMetadata: {
        'ephemeral': 'true',
        'created_at': DateTime.now().toIso8601String(),
      },
    );

    try {
      final UploadTask task = ref.putData(videoBytes, metadata);
      final TaskSnapshot snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }
}
6. TRANSIENT VIDEO KYC & HARD-PURGE LIFECYCLE
Video files bucket storage ko bohot tezi se consume karte hain. Isliye live KYC verification Zero-Retention Ephemeral Pipeline par chalti hai:

[Flutter Client records 3s Live Video (480p, ~1.2 MB)]
                       │
                       ▼
[Uploads directly to gs://.../kyc_ephemeral/{uuid}/kyc_video.mp4]
                       │
                       ▼
[Client invokes FastAPI POST /api/v1/kyc/verify-live]
                       │
                       ▼
[FastAPI streams video directly into RAM buffer (io.BytesIO)]
                       │
                       ▼
[OpenCV extracts 3 frames (15%, 50%, 85%) -> Groq Vision AI evaluates]
                       │
       ┌───────────────┴───────────────┐
       ▼                               ▼
[AUTO-APPROVED (Score >= 85)]    [ESCALATED TO ADMIN DESK]
       │                               │
       │                               ▼
       │                    [Admin resolves in <24h]
       │                               │
       └───────────────┬───────────────┘
                       │
                       ▼
[HARD-PURGE TRIGGERED (app/services/kyc_purge.py)]
- Calls Firebase Admin SDK: bucket.blob(kyc_path).delete()
- Physical video file is DESTROYED permanently.
- RESULT: 0 KB Residual Video Storage!
6.1 Backend Purge Routine (backend/app/services/kyc_purge.py)
Python


import os
import firebase_admin
from firebase_admin import storage
from typing import Optional

def purge_ephemeral_kyc_video(user_id: str) -> bool:
    """
    Permanently deletes ephemeral KYC video from Firebase Cloud Storage.
    Ensures zero video bytes remain in the storage bucket.
    """
    try:
        bucket = storage.bucket()
        blob_path = f"kyc_ephemeral/{user_id}/kyc_video.mp4"
        blob = bucket.blob(blob_path)
        
        if blob.exists():
            blob.delete()
            return True
        return False
    except Exception as e:
        # Log failure to Sentry
        return False
7. PRODUCTION FIREBASE STORAGE SECURITY RULES (storage.rules)
Zero-trust policy enforce karne ke liye Firebase Console mein ye declarative rules deploy honge. Ye ensure karte hain ki:

Koi user doosre user ke folder mein upload na kar sake.

File types strictly image/webp (photos) aur video/mp4 (KYC) hon.

Photo size strictly < 100 KB aur Video size strictly < 5 MB ho.

Ephemeral KYC folder public ke liye 100% invisible rahe.

JavaScript


rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Helper Functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    // 1. PUBLIC / AUTHENTICATED MOMENTS (SLOTS 1 TO 5)
    match /users/{userId}/moments/{fileName} {
      // Anyone authenticated can view approved moments
      allow read: if isAuthenticated();

      // Only the account owner can upload their own slots
      allow write: if isOwner(userId)
                    && request.resource.size < 100 * 1024               // Max 100 KB
                    && request.resource.contentType == 'image/webp'     // Strictly WebP
                    && fileName.matches('slot_[1-5]\\.webp');          // Strictly slots 1 to 5
    }

    // 2. EPHEMERAL KYC VIDEO FOLDER (STRICTLY ISOLATED)
    match /kyc_ephemeral/{userId}/{fileName} {
      // Public / other users CANNOT read KYC videos under any circumstances
      allow read: if false;

      // Only owner can upload during the 3-second verification passage
      allow write: if isOwner(userId)
                    && request.resource.size < 5 * 1024 * 1024          // Max 5 MB
                    && request.resource.contentType == 'video/mp4'      // Strictly MP4
                    && fileName == 'kyc_video.mp4';
    }

    // Block all other paths by default
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
8. STATUTORY DATA ERASURE CASCADE (DPDP ACT 2023 SEC 12)
Jab user Screen 13 par "Delete Account & Erase All Data" confirm karta hai (DELETE /api/v1/auth/incinerate-account), to backend Firebase Admin SDK ke through user ka poora folder recursively destroy karta hai:

Python


def incinerate_user_storage(user_id: str) -> None:
    """
    Completely shreds all media associated with user_id in Firebase Storage.
    Statutory requirement under Section 12 of DPDP Act 2023.
    """
    bucket = storage.bucket()
    prefix = f"users/{user_id}/"
    blobs = bucket.list_blobs(prefix=prefix)
    
    for blob in blobs:
        blob.delete()
        
    # Also purge any dangling KYC file
    kyc_blob = bucket.blob(f"kyc_ephemeral/{user_id}/kyc_video.mp4")
    if kyc_blob.exists():
        kyc_blob.delete()
9. ANTIGRAVITY IMPLEMENTATION & AUDIT ASSERTIONS
Antigravity agent ko Phase 3/4 build karte waqt nimn specifications check karni hain:

Zero Server Media Pass-Through: FastAPI backend par koi multi-part file upload route (/upload-photo) exist nahi karega. Uploads 100% Flutter client direct Firebase SDK se honge.

Metadata Hygiene: Device EXIF data (location coordinates) binary compression level par drop hona chahiye (keepExif: false).

Format Enforcement: Non-WebP uploads Firebase rules ke through reject hone chahiye (HTTP 403 Forbidden).

Purge Verification: KYC verify hote hi Firebase storage mein video blob 0ms mein delete hona chahiye.