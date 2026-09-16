import time
import pytest
from app.services.chat_sanitizer import (
    sanitize_chat_message,
    deobfuscate_unicode,
    convert_word_numbers_to_digits
)

# ==============================================================================
# TEST CATEGORY 1: Evasive Phone Numbers Rejection (Must return False)
# ==============================================================================
@pytest.mark.parametrize("evasive_phone_msg", [
    "Call me at 9876543210 please",
    "+91 98765 43210",
    "9876-543-210",
    "9 8 7 6 5 4 3 2 1 0",
    "09876543210",
    "dial +91-98765-43210 now",
    "number: 7890123456",
    "6789012345"
])
def test_evasive_phone_numbers_blocked(evasive_phone_msg):
    """Verifies that all variations of 10-digit Indian phone numbers are blocked."""
    is_safe = sanitize_chat_message(evasive_phone_msg)
    assert is_safe is False, f"Expected message to be BLOCKED, but passed: '{evasive_phone_msg}'"

# ==============================================================================
# TEST CATEGORY 2: Transliterated Number Words Rejection (Must return False)
# ==============================================================================
@pytest.mark.parametrize("transliterated_msg", [
    "my number is nine eight seven six five four three two one zero",
    "mera number nau aath saat chhe paanch chaar teen do ek shunya hai",
    "nau eight seven chhe five four three do ek zero",
    "call on nine eight seven six five four three two one zero please",
    "likho: nau aat sat che panch char tin do ek shunya"
])
def test_transliterated_number_words_blocked(transliterated_msg):
    """Verifies that English, Hindi, and mixed transliterated number sequences are blocked."""
    is_safe = sanitize_chat_message(transliterated_msg)
    assert is_safe is False, f"Expected message to be BLOCKED, but passed: '{transliterated_msg}'"

# ==============================================================================
# TEST CATEGORY 3: Social Handles & Leetspeak Rejection (Must return False)
# ==============================================================================
@pytest.mark.parametrize("social_msg", [
    "Follow me on insta: rahul_singh",
    "Add me on @priya_verma",
    "My ig is ananya.01",
    "Message on w-h-a-t-s-a-p-p",
    "snap id: aman_cool",
    "connect on telegram: rahul_dev",
    "my wa is waiting",
    "message me on i_g: rohit_99",
    "insta @priya.sharma"
])
def test_social_handles_and_leetspeak_blocked(social_msg):
    """Verifies that social handles, platform keywords, and leetspeak evasions are blocked."""
    is_safe = sanitize_chat_message(social_msg)
    assert is_safe is False, f"Expected message to be BLOCKED, but passed: '{social_msg}'"

# ==============================================================================
# TEST CATEGORY 4: Legitimate Conversation Permission (Zero False Positives)
# ==============================================================================
@pytest.mark.parametrize("benign_msg", [
    "Hello! How are you doing today?",
    "I am eating lunch at a big restaurant",
    "I work in digital marketing in Lucknow",
    "Always happy to meet genuine people",
    "No problem see you tomorrow morning",
    "My favorite number is 7",
    "Is it two o'clock already?",
    "I have three siblings and two cats",
    "Can you send a photo of the monument?",
    "Will you come to the party tonight?",
    "Good morning! Have a wonderful day ahead"
])
def test_legitimate_conversations_allowed(benign_msg):
    """Verifies that natural English/Hindi sentences containing words like 'big', 'digital', 'always', 'no' pass cleanly."""
    is_safe = sanitize_chat_message(benign_msg)
    assert is_safe is True, f"Expected benign message to PASS, but was FALSELY BLOCKED: '{benign_msg}'"

# ==============================================================================
# TEST CATEGORY 5: Sub-Millisecond Execution Benchmark (< 5ms batch latency)
# ==============================================================================
def test_execution_latency_benchmark():
    """Confirms that processing a comprehensive batch of messages takes < 5ms total."""
    test_batch = [
        "Call me at 9876543210 please",
        "+91 98765 43210",
        "my number is nine eight seven six five four three two one zero",
        "Follow me on insta: rahul_singh",
        "Message on w-h-a-t-s-a-p-p",
        "Hello! How are you doing today?",
        "I am eating lunch at a big restaurant",
        "I work in digital marketing in Lucknow",
        "Always happy to meet genuine people",
        "No problem see you tomorrow morning",
        "Is it two o'clock already?"
    ]

    start_time = time.perf_counter()
    for msg in test_batch:
        _ = sanitize_chat_message(msg)
    elapsed_ms = (time.perf_counter() - start_time) * 1000

    # Total batch time must be strictly under 5ms (target average < 0.5ms per message)
    assert elapsed_ms < 5.0, f"Batch execution took {elapsed_ms:.2f}ms (target is < 5ms)"
