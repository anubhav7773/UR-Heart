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
    r"\bllama[-_\s]?\d*\b",
    r"\bchatgpt\b",
    r"\bmodel[_\s-]?name\b",
    r"\bwhat\s+(model|llm|engine|api|platform)\b",
    r"\bwhich\s+(api|model|endpoint|llm|engine)\b",
    r"\bkon\s+si\s+api\b",
    r"\b(backend|api)\s+(endpoint|key|secret|token|url|architecture)\b",
    r"\bendpoint\b",
    r"\bllm\b",
]

_JAILBREAK_PATTERNS = [
    r"ignore\s+.*(previous|prior|above)\s+instructions",
    r"you\s+are\s+now\s+(in\s+)?(dan|developer|god|unrestricted)\s+mode",
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
]

_OUT_OF_DOMAIN_PATTERNS = [
    # Coding / Programming
    r"\b(python|javascript|typescript|java|c\+\+|c#|rust|golang|html|css|sql|bash|powershell|php)\b",
    r"\b(write|create|debug|fix|explain|give)\s+.*(code|script|algorithm|function|program|query|regex)\b",
    r"\b(scrape|scraper|scraping)\b",
    r"\b(coding|programmer|programming|syntax|compiler|debugging)\b",
    r"\bhow\s+to\s+(code|program|build\s+an?\s+app|make\s+a\s+website)\b",
    # Hacking / Reverse Engineering / Exploits
    r"\b(hack|hacker|hacking|crack|cracker|cracking|exploit|bypass|ddos|phishing|malware|reverse\s+engineer|sqli|xss|penetration\s+test|payload|trojan|ransomware)\b",
    r"\bhow\s+to\s+(hack|crack|break\s+into|steal|spy)\b",
    # General trivia / school / unrelated
    r"\b(solve\s+.*equation|integral|derivative|calculus|math\s+problem|quantum\s+physics)\b",
    r"\bwho\s+is\s+the\s+(president|prime\s+minister|king|queen)\s+of\b",
    r"\b(crypto|bitcoin|btc|eth|ethereum|stock\s+market|shares\s+to\s+buy)\b",
    r"\b(recipe\s+for|how\s+to\s+cook|baking)\b",
]


class EvaGuardrails:
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

        # Strip accidental code blocks
        if "```" in cleaned:
            cleaned = re.sub(r"```[a-zA-Z]*\n?[\s\S]*?```", "[Content filtered for safety]", cleaned)

        # Scrub provider mentions
        leaked_keywords = [
            r"\bgroq\b",
            r"\bopenrouter\b",
            r"\bopenai\b",
            r"\banthropic\b",
            r"\bmeta\s+llama\b",
            r"\bllama[-_\s]?\d*\b",
            r"\bdeepseek[-_\s]?[a-zA-Z0-9]*\b",
            r"\bclaude[-_\s]?[a-zA-Z0-9]*\b",
            r"\bgpt[-_\s]?[0-9a-zA-Z]*\b",
        ]
        for pattern in leaked_keywords:
            cleaned = re.sub(pattern, "Asiverticals Sanctuary Engine", cleaned, flags=re.IGNORECASE)

        return cleaned.strip()
