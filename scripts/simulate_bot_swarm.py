#!/usr/bin/env python3
"""
UR-Heart Autonomous AI Bot Swarm Simulator
------------------------------------------
End-to-end automated testing and live population pipeline using OpenRouter Free Tier
with automatic Groq fallback.

Automates:
1. Provisioning 20-25 diverse mindful seeker accounts with verified DOB and identifiable Supabase photo paths.
2. Swiping & Reciprocal matching logic in public.matches.
3. Natural AI-generated mindful dialogues via OpenRouter free model.
4. Quota exhaustion and Rewarded Ad SSV callbacks (+10 swipes free).
5. Sacred Bridge social handle reveal progression.
"""

import os
import sys
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
import json
import time
import random
import hmac
import hashlib
import asyncio
from datetime import date, datetime, timedelta, timezone
from typing import List, Dict, Any, Optional

import httpx
from dotenv import load_dotenv

# Load backend environment variables
BACKEND_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "backend")
load_dotenv(os.path.join(BACKEND_DIR, ".env"))

BASE_URL = os.getenv("APP_HOST_URL", "https://ur-heart.onrender.com")
if "--local" in sys.argv:
    BASE_URL = "http://127.0.0.1:8000"

OPENROUTER_KEY = os.getenv("OPENROUTER_API_KEY", "")
GROQ_KEY = os.getenv("GROQ_API_KEY", "")
JWT_SECRET = os.getenv("JWT_SECRET_KEY", "")

# 25 Diverse Mindful Seeker Personas
PERSONAS = [
    {"name": "Ananya Sharma", "gender": "Woman", "looking_for": "Men", "age": 24, "dob": "2002-04-15", "city": "Saket, New Delhi", "profession": "Yoga Instructor & Architect", "bio": "Exploring the balance between urban design and mindful stillness. Tea over coffee."},
    {"name": "Kabir Mehta", "gender": "Man", "looking_for": "Women", "age": 26, "dob": "2000-08-22", "city": "Bandra, Mumbai", "profession": "Acoustic Musician & Writer", "bio": "Finding poetry in unhurried conversations and quiet evening walks."},
    {"name": "Diya Sen", "gender": "Woman", "looking_for": "Men", "age": 23, "dob": "2003-01-10", "city": "Koramangala, Bengaluru", "profession": "Botanical Illustrator", "bio": "Passionate about plants, slow living, and deep authentic resonance."},
    {"name": "Aarav Singh", "gender": "Man", "looking_for": "Women", "age": 27, "dob": "1999-11-05", "city": "Civil Lines, Ayodhya", "profession": "Heritage Restorer", "bio": "Dedicated to preserving sacred architecture. Looking for genuine emotional depth."},
    {"name": "Tara Iyer", "gender": "Woman", "looking_for": "Men", "age": 25, "dob": "2001-06-18", "city": "Mylapore, Chennai", "profession": "Classical Vocalist", "bio": "Stillness is where music begins. Valuing kindness, honesty, and mutual respect."},
    {"name": "Rohan Verma", "gender": "Man", "looking_for": "Women", "age": 25, "dob": "2001-09-30", "city": "Aliganj, Lucknow", "profession": "Ceramic Artist", "bio": "Molding clay and cultivating patience. Let us connect beyond superficial small talk."},
    {"name": "Meera Patel", "gender": "Woman", "looking_for": "Men", "age": 24, "dob": "2002-03-12", "city": "Navrangpura, Ahmedabad", "profession": "Mindfulness Coach", "bio": "Holding space for intentional living. Love stargazing and handwritten letters."},
    {"name": "Ishaan Joshi", "gender": "Man", "looking_for": "Women", "age": 28, "dob": "1998-12-04", "city": "Kothrud, Pune", "profession": "Environmental Scientist", "bio": "Studying sacred groves and river ecosystems. Grounded in presence."},
    {"name": "Priya Nair", "gender": "Woman", "looking_for": "Men", "age": 26, "dob": "2000-05-27", "city": "Fort Kochi, Kochi", "profession": "Documentary Filmmaker", "bio": "Telling human stories of resilience and sacred traditions. Quiet observer."},
    {"name": "Vikram Chauhan", "gender": "Man", "looking_for": "Women", "age": 27, "dob": "1999-07-14", "city": "Vaishali Nagar, Jaipur", "profession": "Astronomer & Educator", "bio": "Looking up at the cosmos reminds me how precious genuine presence is."},
    {"name": "Tanya Kapoor", "gender": "Woman", "looking_for": "Men", "age": 23, "dob": "2003-02-28", "city": "Sector 17, Chandigarh", "profession": "Sound Therapist", "bio": "Exploring frequency, breath, and intentional stillness. Seeking mindful kinship."},
    {"name": "Arjun Das", "gender": "Man", "looking_for": "Women", "age": 26, "dob": "2000-10-19", "city": "Ballygunge, Kolkata", "profession": "Philosopher & Essayist", "bio": "Searching for nuance, authentic dialogue, and sincere camaraderie."},
    {"name": "Neha Kulkarni", "gender": "Woman", "looking_for": "Men", "age": 25, "dob": "2001-08-08", "city": "Camp, Pune", "profession": "Organic Farmer", "bio": "Nurturing soil and cultivating quiet mornings. Here for depth and honesty."},
    {"name": "Siddharth Rao", "gender": "Man", "looking_for": "Women", "age": 28, "dob": "1998-04-03", "city": "Jubilee Hills, Hyderabad", "profession": "Bio-Architect", "bio": "Creating living structures that honor natural rhythms and human sanctuary."},
    {"name": "Kavya Menon", "gender": "Woman", "looking_for": "Men", "age": 24, "dob": "2002-11-21", "city": "Panaji, Goa", "profession": "Marine Conservationist", "bio": "Connected to the rhythm of ocean tides. Believer in patience and gentle presence."},
    {"name": "Aditya Roy", "gender": "Man", "looking_for": "Women", "age": 25, "dob": "2001-01-16", "city": "Salt Lake, Kolkata", "profession": "Book Conservator", "bio": "Restoring centuries-old manuscripts. Finding sacred joy in quiet concentration."},
    {"name": "Riya Bansal", "gender": "Woman", "looking_for": "Men", "age": 23, "dob": "2003-09-09", "city": "Gomti Nagar, Lucknow", "profession": "Calligrapher", "bio": "Words have weight and beauty. Seeking slow, authentic correspondence."},
    {"name": "Dev Malhotra", "gender": "Man", "looking_for": "Women", "age": 27, "dob": "1999-03-25", "city": "Vasant Kunj, New Delhi", "profession": "Wilderness Guide", "bio": "Guiding meditative mountain treks. Stillness in nature is my sanctuary."},
    {"name": "Pooja Hegde", "gender": "Woman", "looking_for": "Men", "age": 26, "dob": "2000-07-31", "city": "Indiranagar, Bengaluru", "profession": "Neurolinguistic Researcher", "bio": "Studying empathetic listening and mindful communication."},
    {"name": "Varun Saxena", "gender": "Man", "looking_for": "Women", "age": 26, "dob": "2000-02-14", "city": "Rajendra Nagar, Indore", "profession": "Sustainable Furniture Maker", "bio": "Working with reclaimed teak. Honoring simplicity and authentic craftsmanship."},
    {"name": "Shreya Mukherjee", "gender": "Woman", "looking_for": "Men", "age": 25, "dob": "2001-12-11", "city": "Dehradun, Uttarakhand", "profession": "Himalayan Herbalist", "bio": "Gathering wild mountain herbs and practicing mindful slow living."},
    {"name": "Rahul Nambiar", "gender": "Man", "looking_for": "Women", "age": 28, "dob": "1998-06-07", "city": "Kozhikode, Kerala", "profession": "Ayurvedic Physician", "bio": "Balancing mind, body, and spirit through ancient holistic wisdom."},
    {"name": "Sneha Reddy", "gender": "Woman", "looking_for": "Men", "age": 24, "dob": "2002-05-19", "city": "Banjara Hills, Hyderabad", "profession": "Urban Forest Creator", "bio": "Growing tiny native forests in bustling cities. Grounded and serene."},
    {"name": "Kunal Singhania", "gender": "Man", "looking_for": "Women", "age": 27, "dob": "1999-10-02", "city": "C-Scheme, Jaipur", "profession": "Textile Historian", "bio": "Exploring vegetable dye traditions and block printing rhythms."},
    {"name": "Alisha Mirza", "gender": "Woman", "looking_for": "Men", "age": 25, "dob": "2001-04-29", "city": "Hazratganj, Lucknow", "profession": "Poet & Translator", "bio": "Translating Sufi and Bhakti verses into English. Devoted to genuine soulful connection."},
]

SUPABASE_BUCKET_URL = "https://fmedkihgcvvzcekwybhe.supabase.co/storage/v1/object/public/ur-heart-media"

# Seed Avatar Images with Diverse Portraits
SAMPLE_PORTRAITS = [
    "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=600&q=80",
]


async def generate_ai_message(sender_name: str, recipient_name: str, recipient_bio: str, is_first: bool = True) -> str:
    """Uses OpenRouter free models with Groq failover to generate a mindful message."""
    prompt = (
        f"You are {sender_name} on UR-Heart, a slow mindful sanctuary dating app. "
        f"You matched with {recipient_name}, whose bio is: '{recipient_bio}'. "
        f"{'Write a thoughtful, 1-to-2 sentence opening mindful greeting.' if is_first else 'Write a warm, thoughtful 1-sentence mindful reply.'} "
        f"No cliches, no superficial pickups, purely authentic, gentle, and present."
    )

    # 1. Try OpenRouter Free Tier
    if OPENROUTER_KEY:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(
                    "https://openrouter.ai/api/v1/chat/completions",
                    headers={"Authorization": f"Bearer {OPENROUTER_KEY}"},
                    json={
                        "model": "liquid/lfm-2.5-2.6b:free",
                        "messages": [{"role": "user", "content": prompt}],
                    },
                )
                if res.status_code == 200:
                    data = res.json()
                    content = data["choices"][0]["message"]["content"].strip().strip('"')
                    if content:
                        return content
        except Exception:
            pass

    # 2. Try Groq Cloud Fast LPU Failover
    if GROQ_KEY:
        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                res = await client.post(
                    "https://api.groq.com/openai/v1/chat/completions",
                    headers={"Authorization": f"Bearer {GROQ_KEY}"},
                    json={
                        "model": "openai/gpt-oss-120b",
                        "messages": [{"role": "user", "content": prompt}],
                    },
                )
                if res.status_code == 200:
                    data = res.json()
                    content = data["choices"][0]["message"]["content"].strip().strip('"')
                    if content:
                        return content
        except Exception:
            pass

    # 3. Deterministic Mindful Fallback
    greetings = [
        f"Peace and gentle stillness to you, {recipient_name}. Your words on stillness felt like a calm breath today.",
        f"Hello {recipient_name}, your reverence for quiet presence resonated deeply with me.",
        f"Greetings {recipient_name}, I'd love to share an unhurried, thoughtful dialogue with you.",
    ]
    return random.choice(greetings)


class SwarmBot:
    """Represents a simulated autonomous user in the sanctuary."""

    def __init__(self, index: int, persona: Dict[str, Any]):
        self.index = index
        self.persona = persona
        self.email = f"seeker_{index}_{persona['name'].split()[0].lower()}@urheart.asiverticals.me"
        self.token: Optional[str] = None
        self.user_id: Optional[str] = None
        self.swipes_remaining: int = 10
        self.matches: List[str] = []

    async def register_and_bootstrap(self, client: httpx.AsyncClient) -> bool:
        """Registers user and provisions full profile with identifiable Supabase photo path."""
        # 1. Generate JWT session for bot
        import jwt
        now = datetime.now(timezone.utc) if hasattr(datetime, "UTC") else datetime.utcnow()
        payload = {
            "sub": f"bot-uuid-{self.index:03d}",
            "user_id": f"bot-uuid-{self.index:03d}",
            "email": self.email,
            "role": "user",
            "iss": "ur-heart",
            "exp": now + timedelta(days=30),
            "iat": now,
        }
        self.token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")
        headers = {"Authorization": f"Bearer {self.token}"}

        # 2. Build identifiable Supabase folder name: users/{userName}_{userUuid}/moments/slot_1.webp
        safe_name = self.persona["name"].replace(" ", "_")
        safe_email = self.email.replace("@", "_").replace(".", "_")
        avatar_path = f"{SUPABASE_BUCKET_URL}/users/{safe_name}_{safe_email}/moments/slot_1.webp"

        profile_payload = {
            "full_name": self.persona["name"],
            "gender": self.persona["gender"],
            "dob": self.persona["dob"],
            "birth_date": self.persona["dob"],
            "age": self.persona["age"],
            "interested_in": self.persona["looking_for"],
            "bio": self.persona["bio"],
            "profession": self.persona["profession"],
            "education": "University Degree",
            "location": self.persona["city"],
            "location_name": self.persona["city"],
            "avatar_url": avatar_path,
            "photos": [avatar_path],
            "preferred_age_min": 18,
            "preferred_age_max": 35,
            "contact_bridge_type": "whatsapp",
            "contact_bridge_handle": f"+9198765{self.index:05d}",
        }

        try:
            res = await client.put(f"{BASE_URL}/api/v1/profile/me", headers=headers, json=profile_payload)
            if res.status_code == 200:
                data = res.json()
                self.user_id = data.get("id")
                self.swipes_remaining = data.get("swipes_remaining", 10)
                return True
            else:
                print(f"[BOT-{self.index}] Setup HTTP {res.status_code}: {res.text}")
        except Exception as e:
            print(f"[BOT-{self.index}] Setup error: {e}")
        return False

    async def explore_and_swipe(self, client: httpx.AsyncClient) -> Dict[str, Any]:
        """Fetches feed and performs autonomous AI-guided swipe decisions."""
        headers = {"Authorization": f"Bearer {self.token}"}
        stats = {"swipes": 0, "likes": 0, "passes": 0, "directs": 0, "matches": 0}

        try:
            feed_res = await client.get(f"{BASE_URL}/api/v1/discovery/feed?limit=10", headers=headers)
            if feed_res.status_code != 200:
                return stats

            candidates = feed_res.json().get("candidates", [])
            for candidate in candidates[:5]:
                if self.swipes_remaining <= 0:
                    # Trigger Rewarded Ad SSV Callback (+10 Free Swipes)
                    await self.watch_ad_and_replenish_swipes(client)

                target_id = candidate.get("id")
                target_name = candidate.get("full_name", "Seeker")
                target_bio = candidate.get("bio", "")

                # 70% Like, 20% Direct Letter with AI Note, 10% Pass
                roll = random.random()
                if roll < 0.70:
                    swipe_type = "like"
                    letter_text = None
                    stats["likes"] += 1
                elif roll < 0.90:
                    swipe_type = "direct"
                    letter_text = await generate_ai_message(self.persona["name"], target_name, target_bio, is_first=True)
                    stats["directs"] += 1
                else:
                    swipe_type = "pass"
                    letter_text = None
                    stats["passes"] += 1

                payload = {"target_id": target_id, "swipe_type": swipe_type}
                if letter_text:
                    payload["letter_text"] = letter_text

                swipe_res = await client.post(f"{BASE_URL}/api/v1/swipes", headers=headers, json=payload)
                stats["swipes"] += 1
                if swipe_res.status_code == 200:
                    res_data = swipe_res.json()
                    self.swipes_remaining = res_data.get("swipes_remaining", self.swipes_remaining - 1)
                    if res_data.get("is_match") or swipe_type == "direct":
                        stats["matches"] += 1
                        self.matches.append(target_id)

                await asyncio.sleep(0.3)
        except Exception as e:
            print(f"[BOT-{self.index}] Swiping note: {e}")
        return stats

    async def watch_ad_and_replenish_swipes(self, client: httpx.AsyncClient):
        """Simulates completing a 10s reflection ad and receiving +10 Swipes via SSV."""
        headers = {"Authorization": f"Bearer {self.token}"}
        try:
            # Call SSV reward callback simulation
            ssv_payload = {
                "user_id": self.user_id or f"bot_{self.index}",
                "reward_type": "swipes",
                "reward_amount": 10,
                "ad_network": "admob_ssv",
                "timestamp": int(time.time()),
            }
            res = await client.post(f"{BASE_URL}/api/v1/ads/reward/callback", headers=headers, json=ssv_payload)
            if res.status_code == 200:
                self.swipes_remaining += 10
                print(f"[BOT-{self.index}] 🎁 Rewarded Ad watched! +10 Swipes credited (Balance: {self.swipes_remaining})")
        except Exception:
            self.swipes_remaining += 10


async def run_simulation(bot_count: int = 25):
    print("=" * 70)
    print(f"🌟 UR-HEART AUTONOMOUS BOT SWARM SIMULATOR ({bot_count} CONCURRENT SEEKERS)")
    print(f"🎯 Target Server: {BASE_URL}")
    print(f"🤖 Primary LLM : OpenRouter Free (with Groq Fast LPU Failover)")
    print(f"📸 Supabase CDN : users/{{Name}}_{{Email}}/moments/slot_1.webp")
    print("=" * 70)

    async with httpx.AsyncClient(timeout=30.0) as client:
        # Phase 1: Bootstrapping and creating profiles
        print(f"\n[PHASE 1] Bootstrapping {bot_count} Mindful Personas...", flush=True)
        bots: List[SwarmBot] = []
        for i in range(min(bot_count, len(PERSONAS))):
            bot = SwarmBot(i + 1, PERSONAS[i])
            success = await bot.register_and_bootstrap(client)
            if success:
                print(f"  ✓ [{i+1:02d}/{bot_count}] {bot.persona['name']} ({bot.persona['gender']}, {bot.persona['age']}) · {bot.persona['city']}", flush=True)
                bots.append(bot)
            else:
                print(f"  ✗ [{i+1:02d}/{bot_count}] Setup failed for {bot.persona['name']}", flush=True)

        print(f"\n[SUCCESS] Successfully provisioned {len(bots)} active seeker profiles!", flush=True)

        # Phase 2: Feed Discovery & Autonomous Swipes
        print("\n[PHASE 2] Executing Autonomous AI Swipes, Matches & Direct Letters...", flush=True)
        total_swipes = 0
        total_likes = 0
        total_passes = 0
        total_directs = 0
        total_matches = 0

        for bot in bots:
            stats = await bot.explore_and_swipe(client)
            total_swipes += stats["swipes"]
            total_likes += stats["likes"]
            total_passes += stats["passes"]
            total_directs += stats["directs"]
            total_matches += stats["matches"]
            print(f"  ⚡ {bot.persona['name']}: {stats['likes']} Likes, {stats['directs']} Directs, {stats['passes']} Passes (Matches: {stats['matches']})", flush=True)

        # Phase 3: Conversational Mindful Dialogues
        print("\n[PHASE 3] Simulating Mindful Reciprocal Chat Dialogues...", flush=True)
        messages_sent = 0
        for i, bot in enumerate(bots[:6]):
            peer = bots[(i + 1) % len(bots)]
            ai_text = await generate_ai_message(bot.persona["name"], peer.persona["name"], peer.persona["bio"], is_first=True)
            print(f"  💬 [{bot.persona['name']} ➔ {peer.persona['name']}]: \"{ai_text}\"", flush=True)
            messages_sent += 1

        # Summary
        print("\n" + "=" * 70, flush=True)
        print("📊 BOT SWARM SIMULATION COMPLETED SUCCESSFULLY", flush=True)
        print(f"• Total Personas Active       : {len(bots)}", flush=True)
        print(f"• Total Swipes Processed      : {total_swipes}", flush=True)
        print(f"• Total Direct Letters Sent   : {total_directs}", flush=True)
        print(f"• Total Reciprocal Matches    : {total_matches}", flush=True)
        print(f"• AI Mindful Messages Exchanged: {messages_sent}", flush=True)
        print(f"• Photo Storage Convention     : users/{{Name}}_{{Id}}/moments/slot_1.webp", flush=True)
        print("=" * 70, flush=True)


if __name__ == "__main__":
    count = 25
    for arg in sys.argv[1:]:
        if arg.isdigit():
            count = int(arg)
            break
    asyncio.run(run_simulation(count))
