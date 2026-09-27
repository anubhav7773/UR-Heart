# 18_ORIENTATION_SHIELD_AND_LAUNCH_STRATEGY.md: SOCIAL SAFETY SHIELD & HYPERLOCAL DISTRIBUTION
# Project: UR-Heart (Mindful Dating Sanctuary)
# Critical Safety Mandate: Zero Cross-Orientation Leakage (LGBTQ+ Identity Protection in Tier-2/3 Markets)
# Ad Experience: 100% User-Initiated (Zero Automatic Interstitials or Popups)
# Rollout Strategy: Saket PG College (Ayodhya) -> Lucknow University Hubs

---

## 1. THE LGBTQ+ SOCIAL SAFETY SHIELD ("GUPT SANCTUARY")

### 1.1 The Threat Model in Tier-2 & Tier-3 Cities
Ayodhya, Lucknow ya kisi bhi regional college campus mein LGBTQ+ (Gay, Lesbian, Bisexual, Queer) users ke liye sabse bada existential darr **"Forced Outing"** ka hota hai.
* Agar kisi Gay ya Lesbian user ki profile kisi local straight classmate, relative, ya padosi ke feed deck par show ho gayi, to user ko severe social harassment, character assassination, ya family conflict face karna pad sakta hai.
* Standard apps (Tinder/Bumble) aksar algorithm glitch ya loose category matching ke chalte profiles cross-pollinate kar dete hain.

### 1.2 The Non-Negotiable Two-Way Bi-Directional Isolation Rule
UR-Heart mein profile discovery **Strict Two-Way Mutual Filtering** par mathematically lock hai. Koi bhi user doosre user ki screen par tab tak render nahi ho sakta jab tak dono ki preferences ek doosre se **100% reciprocally match** na karein[cite: 1]:

User A (Gender: GA, Interested In: IA)
User B (Gender: GB, Interested In: IB)

FEED VISIBILITY CONDITION:
(GA = IB) AND (GB = IA)


#### Precise Orientation Filtering Truth Table:
| User A (Viewing) | User B (Target Profile) | Can A see B? | Can B see A? | Safety Assessment |
| :--- | :--- | :--- | :--- | :--- |
| **Straight Man** (Man looking for Women) | **Gay Man** (Man looking for Men) | **NEVER (0%)** | **NEVER (0%)** | **100% Safe (Complete Separation)** |
| **Straight Woman** (Woman looking for Men) | **Lesbian Woman** (Woman looking for Women) | **NEVER (0%)** | **NEVER (0%)** | **100% Safe (Complete Separation)** |
| **Gay Man A** (Man looking for Men) | **Gay Man B** (Man looking for Men) | **YES** | **YES** | Safe & Intended Match |
| **Lesbian Woman A** (Woman looking for Women) | **Lesbian Woman B** (Woman looking for Women) | **YES** | **YES** | Safe & Intended Match |
| **Bisexual Man** (Man looking for Everyone) | **Straight Man** (Man looking for Women) | **NEVER (0%)** | **NEVER (0%)** | Protected (Straight man won't see him) |
| **Straight Man** (Man looking for Women) | **Bisexual Woman** (Woman looking for Everyone) | **YES** | **YES** | Valid Reciprocal Match |

---

## 2. PRODUCTION DATABASE QUERY FOR FEED ENGINE (`app/services/discovery_service.py`)

Supabase Postgres engine par feed fetch karte waqt ye query execute hoti hai. Ye SQL clause single-cycle mein execute hota hai aur kisi bhi leak ko database level par hi block kar deta hai[cite: 1]:

```sql
-- Feed Discovery Query with Strict Bi-Directional Gender & Orientation Lock[cite: 1]
SELECT u.id, u.full_name, u.dob, u.bio, u.profession, u.location_name, u.latitude, u.longitude
FROM public.users u
WHERE 
    u.deleted_at IS NULL
    AND u.kyc_status = TRUE[cite: 1]
    AND u.id <> :current_user_id
    -- 1. Exclude already swiped profiles (Pass or Like)[cite: 1]
    AND u.id NOT IN (
        SELECT target_id FROM public.swipes WHERE actor_id = :current_user_id[cite: 1]
    )
    -- 2. Exclude blocked perimeter[cite: 1]
    AND u.id NOT IN (
        SELECT blocked_id FROM public.blocked_users WHERE blocker_id = :current_user_id[cite: 1]
        UNION
        SELECT blocker_id FROM public.blocked_users WHERE blocked_id = :current_user_id[cite: 1]
    )
    -- 3. STRICT BI-DIRECTIONAL ORIENTATION SHIELD:
    -- Target's gender must match what Current User is looking for[cite: 1]
    AND (
        (:current_user_interested_in = 'Everyone')
        OR (u.gender = :current_user_interested_in)
    )
    -- AND Current User's gender must match what Target is looking for[cite: 1]
    AND (
        (u.interested_in = 'Everyone')
        OR (u.interested_in = :current_user_gender)
    )
    -- 4. Incognito Shield Check (Ghost Cloak)
    AND (u.is_incognito = FALSE)
    -- 5. Age Preference Filter
    AND (
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, u.dob)) BETWEEN :current_user_age_min AND :current_user_age_max
    )
ORDER BY u.created_at DESC
LIMIT 20;
3. THE GHOST CLOAK (INCOGNITO MODE FOR VULNERABLE USERS)
Screen 13 par Incognito Stream Radius toggle diya gaya hai. Conservative tier-2 cities ke queer users ya privacy-conscious users ke liye ye feature lifesaver hai:   
PNG
+ 1

[User enables Incognito Mode in Settings][cite: 14, 27]
                       │
                       ▼
┌────────────────────────────────────────────────────────────────────────┐
│ users.is_incognito = TRUE                                              │
│ - User's profile is REMOVED from the public discovery feed entirely.   │
│ - Zero people in Ayodhya or Lucknow can stumble upon this profile.     │
└──────────────────────┬─────────────────────────────────────────────────┘
                       │
                       ▼
┌────────────────────────────────────────────────────────────────────────┐
│ HOW INCOGNITO USER MATCHES:                                            │
│ 1. Incognito user can still browse the public Feed deck quietly.       │
│ 2. When Incognito user taps "Like" or sends a "Direct Letter":         │
│    -> Their card is ONLY revealed to that specific person in their     │
│       "Resonances (Liked You)" screen[cite: 8, 21].                                  │
│ 3. RESULT: 100% Controlled Exposure. Only people they approve ever see │
│    their existence.                                                    │
└────────────────────────────────────────────────────────────────────────┘
4. STRICT ZERO-INTERRUPTION AD GOVERNANCE (SANCTUARY AMBIENCE)
App ke andar kisi bhi screen par koi automatic pop-up, auto-playing video banner, ya interstitial ad trigger nahi hoga.   
PNG
+ 3

4.1 Strict Ad Rules
Zero Auto-Interrupt: User jab photo dekh raha ho, bio padh raha ho, ya chat kar raha ho, tab 0% ads render honge.   
PNG
+ 1

Exclusively User-Initiated: Ads sirf tabhi chalenge jab user voluntary taur par Screen 10 (Growth Hub) mein jakar button tap kare ya feed par daily swipes khatam hone par explicitly confirm kare:   
PNG
+ 2

"Out of Swipes. Take a 10s Mindful Reflection to gather +10 Skips?"

   
PNG
+ 1

No Betting/Gambling Ads: Google AdMob console mein Category Blocking Rules configure honge:

Blocked Categories: Gambling & Betting, Casino Games, Sensational/Clickbait, Cryptocurrency Speculation.

Allowed Categories: Education, Wellness & Mental Health, Travel & Hospitality, FMCG/Lifestyle.

5. HYPERLOCAL ROLLOUT PLAYBOOK: SAKET PG COLLEGE TO LUCKNOW
Dating apps national launch par ghost town ban jati hain. UR-Heart Hyperlocal Campus Cluster Playbook follow karega:

[PHASE A: SAKET PG COLLEGE (AYODHYA)] 
-> Goal: 1,500 Dense Active Users 
                │
                ▼
[PHASE B: GREATER AYODHYA & FAIZABAD HUB] 
-> Civil Lines, Naka, Cantt Youth Hubs (5,000 MAU)
                │
                ▼
[PHASE C: LUCKNOW UNIVERSITY NETWORK] 
-> LU Campus, BBD University, Amity Lucknow, IET, Gomti Nagar Hubs (25,000 MAU)
5.1 Phase A: Saket PG College (Ayodhya) Activation
Target Audience: LLB, BA, B.Sc students, nearby PG hostels, local cafes.

Campus Ambassador & Influencer Hook:

Ayodhya ke local student creators aur campus leaders ko onboard karna.

The Core Hook: "Tinder aur Bumble par fake profiles aur loot machi hai. UR-Heart par bina single paisa diye, AI-verified college profiles se baat karo with 100% screenshot-protected privacy."

The Liquidity Metric: Jab Saket PG College ke 800 ladke aur 400 ladkiyan register ho jayengi, to har student ko card deck par apne campus ke relatable faces dikhenge. Mutual matching speed 10x ho jayegi.   
PNG
+ 1

5.2 Phase B: Lucknow Expansion
Ayodhya cluster prove hone ke baad Lucknow ke college corridors (Hazratganj, Gomti Nagar, Aliganj) ko target kiya jayega.

Distance radius filter automatically 5 km se 15 km extend ho jayega taaki Ayodhya aur Lucknow commute karne wale young professionals organically bridge create karein.

overall ek user se dusre user ke bich ka distance maximmum 200 km aur minimum 0 mtr. distance ke user visible honge.