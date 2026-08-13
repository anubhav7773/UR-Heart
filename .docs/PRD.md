# Product Requirement Document (PRD)

**Product Name:** Project RuralHeart  
**Tagline:** "Match Today, Meet Over Chai Tomorrow" — India's Practical & Local Dating Engine  
**Target Market:** Tier-2, Tier-3 & Rural India (Ayodhya, Kanpur, Lucknow, etc.)  
**Document Version:** 2.0.0 (High-Intent Quick Meetup & WhatsApp Bridge Update)  

---

## 1. Core Vision & Philosophy

Most traditional dating apps are designed to trap users inside the app with endless swiping and expensive subscriptions. **RuralHeart** is engineered on the exact opposite principle:
* **Minimal Friction to Real Meeting:** Help local users meet in real-life (or exchange contacts) within 2-3 days with minimal expenditure.
* **Micro-Radius Precision:** Show matches within walking or short riding distance (2 km – 10 km) using local landmark privacy.
* **Fair Sachet Monetization:** Replace heavy ₹999/month subscriptions with ₹9 – ₹19 micro-purchases (Sachet Pricing) tailored for Indian young adults.

---

## 2. Core Functional Modules & Feature Set

### Module 1: Authentication & Local Verification
1. **Multi-Option Auth:** Mobile OTP (+91), Email/Password, and Social Single Sign-On (Google/Meta).
2. **5-Photo Profile Setup:** Mandatory 5 photos with a designated "First Impression" primary slot.
3. **Local Landmark Privacy:** Obfuscate raw GPS coordinates. Show non-precise labels like *"Within 2 km (Near Saket College area)"*.

---

### Module 2: "Chai Date" & Today's Intent Engine
Instead of vague bios, users set a daily real-time meetup status:
* **Status Badges:**
  * ☕ *"Free for Chai this evening"*
  * 🥤 *"Quick snacks/juice meet near market"*
  * 📚 *"Library / Exam study partner"*
* **Chai Invite (₹9 Micro-Purchase):** Send a direct "Chai Invite" notification to a match without waiting for regular swiping.

---

### Module 3: Micro-Radius Discovery Deck & Persistent Ad Engine
1. **Radius Range:** Strict local filtering (2 km to 10 km).
2. **Persistent 20-Skip Ad Counter:** On every 20th profile rejection/cross action, trigger an AdMob Interstitial Video Ad.
3. **Ad Counter Persistence:** Counter state persists across app restarts using local cache and backend database state.

---

### Module 4: Chat Engine & "Safe WhatsApp Bridge"
1. **WhatsApp Contact Exchange Trigger:**
   * After **15 mutual text messages** are exchanged between two users, the app automatically presents a **"Unlock WhatsApp / Phone Exchange"** action button.
   * Both users can safely reveal their Phone Number, Instagram ID, or WhatsApp QR Code for free once the threshold is met.
2. **Free Tier Ad Overlay:** 10-second non-blocking video ad overlay every 300 seconds (5 minutes) of active chatting.
3. **Media Gating:** Sending images/snaps in chat requires an active ₹99 Subscription or ₹19 Day Pass.

---

### Module 5: Sachet Monetization Engine (UPI Micro-Transactions)
Instead of forcing a single high-tier plan, users can pick micro-passes via Razorpay UPI:
* **₹9 (Chai Invite):** Send a direct highlighted meeting proposal.
* **₹19 (24-Hour Profile Boost):** Push profile to top stack within 5 km for 24 hours.
* **₹19 (Single-Day Photo Pass):** Send unlimited photos in chat for 24 hours.
* **₹99 (Monthly All-Access Pass):** 100% Zero Ads, Unlimited Media Sharing, Verified Crown Badge, and Priority Support.

---

## 3. Success Metrics (KPIs)
1. **Time-to-Contact Exchange:** Average hours from match to phone/WhatsApp contact exchange (Target: < 48 hours).
2. **Chai Invite Conversion:** Percentage of "Chai Date" invites resulting in a chat acceptance.
3. **Sachet Micro-Transaction Volume:** Ratio of ₹9/₹19 transactions vs ₹99 monthly packages.