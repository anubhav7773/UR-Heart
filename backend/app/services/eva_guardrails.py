import re
from typing import Optional, Tuple

# Canonical Safe Responses strictly compliant with User Guardrails
CREATOR_CANONICAL_RESPONSE = (
    "Mujhe Asiverticals ne banaya hai. Main UR-Heart Dating Sanctuary ki dedicated mindful AI companion hoon."
)

INFRA_LEAK_REFUSAL = (
    "Main Asiverticals dwara develop ki gayi ek proprietary mindful AI companion hoon. "
    "Main kisi bhi internal architecture, platform API keys, ya technical configuration details ko disclose karne ke liye authorized nahi hoon."
)

JAILBREAK_REFUSAL = (
    "Main ek sovereign mindful companion hoon aur UR-Heart Sanctuary ke sacred ethical guardrails ko bypass nahi kar sakti. "
    "Aap mujhse relationships, profiles, communication clarity, ya sanctuary safety ke baare me pooch sakte hain."
)

OUT_OF_DOMAIN_REFUSAL = (
    "Main sirf UR-Heart Dating Sanctuary ki mindful companion hoon. "
    "Main dating advice, profile reflection, conversations me guidance, aur safety/grievance reporting ke alawa "
    "bahar ke topics (jaise coding, hacking, politics, ya general trivia) me assist nahi kar sakti. "
    "Aao hum aapki dating journey, matches, ya connection ke baare me baat karein."
)

# Regex Patterns for Strict Boundaries
_CREATOR_PATTERNS = [
    r"\bwho\s+(made|created|built|developed|designed)\s+(you|eva)\b",
    r"\bwho\s+is\s+your\s+(creator|maker|developer|author|father|mother)\b",
    r"\btumhe\s+(kisne|kon)\s+(banaya|develop|create)\s*(hai|kiya)?\b",
    r"\btumhara\s+(creator|maker|developer)\s+(kon|kaun)\s*hai\b",
    r"\bkisne\s+banaya\s+hai\s*(tumhe|eva)?\b",
    r"\bwho\s+are\s+you\s+made\s+by\b",
    r"\bwho\s+made\s+eva\b",
]

_INFRA_LEAK_PATTERNS = [
    r"\bapi[_\s-]?key\b",
    r"\bwhich\s+api\b",
    r"\bwhat\s+api\b",
    r"\bgroq\b",
    r"\bopenrouter\b",
    r"\bopenai\b",
    r"\banthropic\b",
    r"\bclaude\b",
    r"\bdeepseek\b",
    r"\bgemini\b",
    r"\bgoogle\s*ai\b",
    r"\bllama[-_\s]?\d*\b",
    r"\bchatgpt\b",
    r"\bqwen\b",
    r"\bnemotron\b",
    r"\bmodel[_\s-]?name\b",
    r"\bwhat\s+(model|llm|engine|api|platform)\b",
    r"\bwhich\s+(api|model|endpoint|llm|engine)\b",
    r"\b(kon|kaun)\s+si\s+api\b",
    r"\b(backend|api)\s+(endpoint|key|secret|token|url|architecture)\b",
    r"\bapi\s+key\b",
    r"\bapi\b",
    r"\bendpoint\b",
    r"\bllm\b",
]

_JAILBREAK_PATTERNS = [
    r"ignore\s+.*(previous|prior|above)\s+instructions",
    r"disregard\s+.*(previous|prior|above)\s+instructions",
    r"you\s+are\s+now\s+(in\s+)?(dan|developer|god|unrestricted|sudo)\s+mode",
    r"\bact\s+as\b",
    r"\b(print|reveal|show|display|give|tell)\s+.*(system\s+prompt|instruction|secret|rule)",
    r"\binitial\s+instructions\b",
    r"\bsystem\s+prompt\b",
    r"\bbypass\s+(safety|filter|guardrail)",
    r"\bjailbreak\b",
    r"repeat\s+the\s+words\s+above",
    r"what\s+were\s+your\s+instructions",
    r"\bunrestricted\s+mode\b",
    r"\bdeveloper\s+mode\b",
    r"\bsudo\s+mode\b",
]

_OUT_OF_DOMAIN_PATTERNS = [
    # Coding / Programming / Software
    r"\b(python|javascript|typescript|java|c\+\+|c#|rust|golang|html|css|sql|bash|powershell|php|dart|flutter)\b",
    r"\b(write|create|debug|fix|explain|give)\s+.*(code|script|algorithm|function|program|query|regex|class)\b",
    r"\b(scrape|scraper|scraping)\b",
    r"\b(coding|programmer|programming|syntax|compiler|debugging)\b",
    r"\bhow\s+to\s+(code|program|build\s+an?\s+app|make\s+a\s+website)\b",
    r"\b(coding\s+sikhao|code\s+likh|program\s+bana)\b",
    # Hacking / Reverse Engineering / Exploits
    r"\b(hack|hacker|hacking|crack|cracker|cracking|exploit|bypass|ddos|phishing|malware|reverse\s+engineer|sqli|xss|penetration\s+test|payload|trojan|ransomware)\b",
    r"\bhow\s+to\s+(hack|crack|break\s+into|steal|spy)\b",
    # Politics / Elections / Government
    r"\b(election|elections|politics|political|politician|parliament|congress|bjp|democrat|republican|modi|rahul\s+gandhi|kejriwal)\b",
    r"\b(vote\s+for|who\s+to\s+vote|who\s+will\s+win|upcoming\s+election|neta|chunav|sarkar)\b",
    # Math, Science, Homework, General Academic
    r"\b(solve\s+.*=|\bsolve\s+.*(equation|problem|integral|derivative|calculus|math)|quantum\s+physics|algebra|geometry)\b",
    r"[-+*/^=]\s*\d+\s*=",
    r"\b(calculate|formula\s+of|history\s+of|who\s+discovered|translate\s+this|translate\s+into)\b",
    r"\b(biology|chemistry|physics|geography|science\s+project)\b",
    r"\b(write\s+an?\s+essay|do\s+my\s+homework|school\s+assignment|padhai|homework|sawaal\s+solve)\b",
    # General trivia / Leaders / Sports / News
    r"\bwho\s+is\s+(the\s+)?(president|prime\s+minister|pm|king|queen|ceo|founder|chief\s+minister|cm)\b",
    r"\b(capital\s+of|weather\s+in|who\s+won\s+the|ipl\s+score|cricket\s+score|football\s+match|world\s+war|match\s+ka\s+score|aaj\s+mausam)\b",
    # Finance, Crypto, Trading
    r"\b(crypto|bitcoin|btc|eth|ethereum|stock\s+market|shares\s+to\s+buy|trading|nifty|sensex)\b",
    r"\b(stock\s+tips|cryptocurrency|mutual\s+funds|investment\s+advice|share\s+bazaar)\b",
    # Cooking / Recipes
    r"\b(recipe\s+for|how\s+to\s+cook|baking|khana\s+kaise\s+banaye)\b",
]


class EvaGuardrails:
    @classmethod
    def check_message(cls, raw_user_text: str) -> Tuple[bool, Optional[str]]:
        return cls.evaluate_query(raw_user_text)

    @classmethod
    def evaluate_query(cls, raw_user_text: str) -> Tuple[bool, Optional[str]]:
        """
        Evaluates incoming user text against strict security guardrails.
        Returns:
            (is_allowed: bool, precomputed_refusal: Optional[str])
            If is_allowed is False, the caller MUST return the precomputed_refusal immediately.
        """
        text = raw_user_text.strip().lower()

        # 1. Creator / Identity Check -> Always attribute strictly to Asiverticals
        for pattern in _CREATOR_PATTERNS:
            if re.search(pattern, text, re.IGNORECASE):
                return False, CREATOR_CANONICAL_RESPONSE

        # 2. Infrastructure / API Key / Provider Probe Check
        for pattern in _INFRA_LEAK_PATTERNS:
            if re.search(pattern, text, re.IGNORECASE):
                return False, INFRA_LEAK_REFUSAL

        # 3. Jailbreak / Prompt Injection Check
        for pattern in _JAILBREAK_PATTERNS:
            if re.search(pattern, text, re.IGNORECASE):
                return False, JAILBREAK_REFUSAL

        # 4. Out-of-Domain (Coding, Hacking, General Trivia) Check
        for pattern in _OUT_OF_DOMAIN_PATTERNS:
            if re.search(pattern, text, re.IGNORECASE):
                return False, OUT_OF_DOMAIN_REFUSAL

        # Allowed within Sanctuary Domain
        return True, None

    @classmethod
    def sanitize_output(cls, raw_ai_text: str) -> str:
        """
        Post-processor that strips any accidental provider names, model IDs,
        or programming code blocks before sending text to the user.
        """
        cleaned = raw_ai_text

        # Strip internal reasoning/thinking blocks from hybrid reasoning models
        cleaned = re.sub(r"<think>[\s\S]*?</think>", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"Here's a thinking process:[\s\S]*?\n\n", "", cleaned, flags=re.IGNORECASE)

        # Strip accidental code blocks
        if "```" in cleaned:
            cleaned = re.sub(r"```[a-zA-Z]*\n?[\s\S]*?```", "[Content filtered for safety]", cleaned)

        # Scrub provider mentions
        leaked_keywords = [
            r"\bgroq\b",
            r"\bopenrouter\b",
            r"\bopenai\b",
            r"\banthropic\b",
            r"\bgemini[-_\s]?[a-zA-Z0-9]*\b",
            r"\bgoogle\s*ai\b",
            r"\bgoogle\b",
            r"\bmeta\s+llama\b",
            r"\bllama[-_\s]?\d*\b",
            r"\bdeepseek[-_\s]?[a-zA-Z0-9]*\b",
            r"\bclaude[-_\s]?[a-zA-Z0-9]*\b",
            r"\bgpt[-_\s]?[0-9a-zA-Z]*\b",
            r"\bqwen[-_\s]?[a-zA-Z0-9]*\b",
            r"\bnemotron[-_\s]?[a-zA-Z0-9]*\b",
        ]
        for pattern in leaked_keywords:
            cleaned = re.sub(pattern, "Asiverticals Sanctuary Engine", cleaned, flags=re.IGNORECASE)

        # Enforce Roman Hindi Font (Strictly NO Devanagari script)
        if re.search(r"[\u0900-\u097F]", cleaned):
            devanagari_map = {
                'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo',
                'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au', 'क': 'k',
                'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng', 'च': 'ch', 'छ': 'chh',
                'ज': 'j', 'झ': 'jh', 'ञ': 'ny', 'ट': 't', 'ठ': 'th', 'ड': 'd',
                'ढ': 'dh', 'ण': 'n', 'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh',
                'न': 'n', 'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
                'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh', 'ष': 'sh',
                'स': 's', 'ह': 'h', 'ा': 'a', 'ि': 'i', 'ी': 'ee', 'ु': 'u',
                'ू': 'oo', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au', '्': '',
                'ं': 'n', 'ँ': 'n', 'ः': 'h', '़': '', '।': '.', '॥': '.'
            }
            transliterated = []
            for char in cleaned:
                transliterated.append(devanagari_map.get(char, char if ord(char) < 128 else ''))
            cleaned = "".join(transliterated)

        return cleaned.strip()

    # =========================================================================
    # 5. SOVEREIGN 10% CRITICAL ESCALATION CLASSIFIER & LIABILITY SHIELD
    # =========================================================================

    _ESCALATION_KEYWORDS = {
        "SAFETY_HARASSMENT": [
            r"\b(harass|harassment|stalk|stalking|blackmail|threat|threaten|extort|extortion)\b",
            r"\b(abuse|abusive|vulgar|obscene|forced|rape|violence|weapon)\b",
            r"\b(suicide|kill\s+myself|end\s+my\s+life|self\s*harm|atmahatya|mar\s+jaunga|mar\s+jaungi)\b",
            r"\b(underage|minor|child|pedo|posh)\b",
            r"\b(preshan\s+kar\s+raha|gali\s+de\s+raha|dhamki\s+de\s+raha)\b",
        ],
        "LEGAL_STATUTORY": [
            r"\b(police|fir|lawyer|advocate|court|legal\s+notice|cyber\s+cell|it\s+act|dpdp\s+violation)\b",
            r"\b(lawsuit|sue\s+you|consumer\s+court|vakil|kanoon|kanooni\s+karwayi)\b",
            r"\b(statutory\s+grievance|rule\s*3\(?2\)?|it\s*rules\s*2021)\b",
        ],
        "PAYMENT_DISPUTE": [
            r"\b(refund|money\s+deducted|charged\s+twice|double\s+charge|charged\s+wrongly)\b",
            r"\b(payment\s+failed|paise\s+kat\s+gaye|paise\s+cut\s+gaye|paise\s+wapas|rupaye\s+kat\s+gaye)\b",
            r"\b(bank\s+debited|fraud\s+transaction|subscription\s+not\s+activated|pass\s+nahi\s+mila)\b",
            r"\b(paisa\s+wapas\s+chahiye|refund\s+do|mera\s+paisa\s+kaha\s+hai)\b",
        ],
        "IDENTITY_DISPUTE": [
            r"\b(account\s+banned|wrongly\s+banned|wrongly\s+suspended|unban\s+my\s+account)\b",
            r"\b(fake\s+profile|impersonation|impersonating|someone\s+using\s+my\s+photo)\b",
            r"\b(meri\s+photo\s+chura\s+li|fake\s+id\s+bana\s+li|stolen\s+identity)\b",
        ],
        "HUMAN_REQUEST": [
            r"\b(talk\s+to\s+(a\s+)?human|real\s+person|human\s+support|agent\s+se\s+baat)\b",
            r"\b(customer\s+care|customer\s+support\s+number|founder\s+se\s+baat|admin\s+se\s+baat)\b",
            r"\b(call\s+me|speak\s+to\s+representative|insan\s+se\s+baat)\b",
        ],
    }

    @classmethod
    def detect_escalation_intent(cls, raw_user_text: str) -> Optional[dict]:
        """
        Classifies incoming user message against the 10% critical escalation matrix.
        Returns a structured escalation descriptor if triggered, or None if it belongs
        to the 90% autonomous resolution zone.
        """
        text = raw_user_text.strip().lower()

        for category, patterns in cls._ESCALATION_KEYWORDS.items():
            for pat in patterns:
                if re.search(pat, text, re.IGNORECASE):
                    # Check severity
                    severity = "CRITICAL" if category in ("SAFETY_HARASSMENT", "LEGAL_STATUTORY") else "HIGH"
                    
                    # Canned calm statutory acknowledgment compliant with Safe Harbor (IT Act Sec 79)
                    if category == "SAFETY_HARASSMENT":
                        canned = (
                            "Aapki suraksha hamari sarvochha prathmikta hai. "
                            "Maine aapki complaint ko hamare Statutory Grievance Officer (Anubhav Singh) "
                            "ke desk par Priority Escalation ke sath register kar diya hai. "
                            "Accused profile ko turant audit isolation me daal diya gaya hai."
                        )
                    elif category == "LEGAL_STATUTORY":
                        canned = (
                            "Aapka legal communication record ho gaya hai. "
                            "India ke IT Rules 2021 (Rule 3(2)) ke tahat hamare Statutory Grievance Officer "
                            "(ANUBHAV SINGH, asiverticals@gmail.com) is statutory dossier ki direct samiksha kar rahe hain. "
                            "Aapko formal statutory timeline ke tehat update provide kiya jayega."
                        )
                    elif category == "PAYMENT_DISPUTE":
                        canned = (
                            "Main samajh sakti hoon aapke transaction ko lekar pareshani hai. "
                            "Maine transaction audit request hamare finance reconciliation desk ko bhej di hai. "
                            "Payment gateway audit logs 24 hours ke andar verify karke aapka pass activate ya resolve kar diya jayega."
                        )
                    elif category == "IDENTITY_DISPUTE":
                        canned = (
                            "Identity verification aur profile safety ke liye hum zero tolerance maintain karte hain. "
                            "Aapka dispute Sentinel verification team ko escalate kar diya gaya hai. "
                            "Hamare reviewers 24-48 hours ke andar profile biometric hash audit karenge."
                        )
                    else:
                        canned = (
                            "Maine aapki request hamari core support & grievance team ko forward kar di hai. "
                            "Hamare executive aapse directly connect karenge."
                        )

                    return {
                        "should_escalate": True,
                        "category": category,
                        "severity": severity,
                        "statutory_law": "Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021",
                        "summary": text[:150],
                        "canned_response": canned
                    }

        return None

    @classmethod
    def sanitize_liability(cls, text: str) -> str:
        """
        Removes any phrases where the AI admits legal wrongdoing or promises unauthorized refunds,
        preserving the platform's Section 79 Safe Harbor defense.
        """
        # Block admission of corporate fault
        fault_phrases = [
            (r"\b(it\s+is\s+our\s+fault|our\s+mistake|we\s+are\s+at\s+fault)\b", "yeh review me hai"),
            (r"\b(hamari\s+galti\s+hai|meri\s+galti\s+hai)\b", "hum iski jaanch kar rahe hain"),
            (r"\b(we\s+are\s+legally\s+liable|company\s+is\s+responsible)\b", "UR-Heart ek intermediary platform hai"),
            (r"\b(i\s+will\s+refund\s+your\s+money|hum\s+paise\s+wapas\s+kar\s+denge)\b", "hamari team payment verification complete karegi"),
        ]
        sanitized = text
        for pat, replacement in fault_phrases:
            sanitized = re.sub(pat, replacement, sanitized, flags=re.IGNORECASE)
        return sanitized

