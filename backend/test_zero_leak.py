"""
Comprehensive Zero-Leak Content Guard Test Suite
Tests all evasion techniques: unicode, leetspeak, word-numbers, spacing, etc.
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from app.services.content_guard import sanitize_and_guard_message


def test_zero_leak_enforcement():
    """Test suite covering all leak detection scenarios."""

    test_cases = [
        # ============================================================
        # SHOULD BLOCK (True = leak detected)
        # ============================================================

        # --- Standard Phone Numbers ---
        ("My number is 9876543210", True, "Standard 10-digit"),
        ("Call me at 8765432109", True, "Another valid mobile"),
        ("+919876543210", True, "International format"),
        ("919876543210", True, "With country code"),
        ("09876543210", True, "With 0 prefix"),

        # --- Spaced/Punctuated Phone Numbers ---
        ("Call me 98765 43210", True, "Spaced digits"),
        ("9 8 7 6 5 4 3 2 1 0", True, "Fully spaced"),
        ("987-654-3210", True, "Hyphen separated"),
        ("987.654.3210", True, "Dot separated"),
        ("987_654_3210", True, "Underscore separated"),
        ("9876/543/210", True, "Slash separated"),
        ("98-76-54-32-10", True, "Alternate spacing"),

        # --- Word-Based Phone Numbers (English) ---
        ("nine eight seven six five four three two one zero", True, "English words"),
        ("My num: nine eight seven six five four three two one zero", True, "English in sentence"),
        ("Call me at eight seven six five four three two one zero", True, "Partial English"),

        # --- Word-Based Phone Numbers (Hinglish) ---
        ("ek do teen char panch chhe saat aath nau shunya", True, "Hinglish words"),
        ("Mera number hai nau aath saat chhe panch char teen do ek", True, "Hinglish in sentence"),

        # --- Unicode Phone Numbers ---
        ("Contact: ९८७६५४३२१०", True, "Devanagari digits"),
        ("Call ①②③④⑤⑥⑦⑧⑨⑩", True, "Circled digits"),
        ("My no: ０９８７６５４３２１", True, "Fullwidth digits"),

        # --- Leetspeak Obfuscation ---
        ("n1ne e1ght s3ven s1x f1ve f0ur thr3e tw0 0ne zer0", True, "Leetspeak numbers"),
        ("c@ll me @t n1ne e!ght seven s!x", True, "Mixed leetspeak"),

        # --- Social Media Handles ---
        ("Add me on insta @cool_user99", True, "Instagram handle"),
        ("My insta: john_doe123", True, "Instagram without @"),
        ("Follow me @priya_sharma", True, "Generic @ handle"),
        ("DM me on snap cooluser07", True, "Snapchat handle"),
        ("WhatsApp me @user_name_23", True, "WhatsApp handle"),
        ("Telegram: @alpha_beta99", True, "Telegram handle"),
        ("My handle is awesome_guy42", True, "Generic handle with digits"),

        # --- Social Platform Keywords ---
        ("Add me on instagram", True, "Instagram keyword"),
        ("My WhatsApp id", True, "WhatsApp keyword"),
        ("DM me on telegram", True, "Telegram keyword"),
        ("Find me on snap", True, "Snapchat keyword"),
        ("Contact me on fb", True, "Facebook keyword"),

        # --- UPI IDs ---
        ("Pay me at 9876543210@paytm", True, "UPI with phone"),
        ("My UPI: user@okaxis", True, "UPI bank handle"),
        ("Send money to john@ybl", True, "UPI PhonePe"),
        ("UPI ID: user123@oksbi", True, "UPI SBI"),

        # --- Email Addresses ---
        ("Email me at john.doe@gmail.com", True, "Gmail address"),
        ("Contact: user@example.com", True, "Generic email"),
        ("priya.sharma@outlook.com", True, "Outlook email"),

        # --- Contact Keywords ---
        ("Call me", True, "Call keyword"),
        ("Contact me", True, "Contact keyword"),
        ("My number hai", True, "Hinglish number keyword"),
        ("Mera num", True, "Hinglish num keyword"),
        ("Phone me", True, "Phone keyword"),
        ("Ping me", True, "Ping keyword"),

        # --- Mixed Evasion Techniques ---
        ("Call m3 @t n!ne e1ght 7 6 f1ve f0ur thr33 tw0 1 zer0", True, "Leetspeak + spacing"),
        ("My नंबर: ९८७६५४३२१०", True, "Hindi word + Devanagari"),
        ("insta @john_doe99 call 9876543210", True, "Multiple leaks"),

        # --- Zero-Width Character Injection ---
        ("98​76​54​32​10", True, "Zero-width spaces"),

        # ============================================================
        # SHOULD ALLOW (False = safe message)
        # ============================================================

        # --- Normal Conversation ---
        ("Hey, how are you?", False, "Greeting"),
        ("I love chai and samosas", False, "Food talk"),
        ("What are your hobbies?", False, "Question"),
        ("My favorite movie is Inception", False, "Movie discussion"),
        ("Let's meet at the cafe tomorrow", False, "Meet plan"),
        ("I work in tech", False, "Career talk"),
        ("Born and raised in Mumbai", False, "Location general"),

        # --- Numbers in Context (Safe) ---
        ("I have 2 cats and 1 dog", False, "Pet count"),
        ("Born in 1995", False, "Birth year"),
        ("Let's meet at 3 PM", False, "Time"),
        ("Apartment 23, Floor 5", False, "Address number"),
        ("I'm 25 years old", False, "Age"),
        ("My favorite number is 7", False, "Favorite number"),
        ("I watched 5 movies last week", False, "Count"),

        # --- Common Words with Numbers ---
        ("COVID19 is serious", False, "COVID19"),
        ("Web3 is the future", False, "Web3"),
        ("I live on level2", False, "Level2"),
        ("Room2 is upstairs", False, "Room2"),

        # --- Safe Keywords in Context ---
        ("I love making new contacts", False, "Contact as noun"),
        ("Can you call the waiter?", False, "Call as action"),
        ("What's your favorite number?", False, "Number in question"),

        # --- Emojis and Expressions ---
        ("😊 Nice to meet you!", False, "Emoji greeting"),
        ("That's so cool! 🔥", False, "Expression with emoji"),
        ("💯 Agree with you", False, "100 emoji"),
    ]

    print("=" * 80)
    print("ZERO-LEAK CONTENT GUARD TEST SUITE")
    print("=" * 80)
    print()

    passed = 0
    failed = 0
    failures = []

    for text, should_block, description in test_cases:
        result = sanitize_and_guard_message(text)
        expected = "BLOCK" if should_block else "ALLOW"
        actual = "BLOCK" if result else "ALLOW"

        if result == should_block:
            status = "✅ PASS"
            passed += 1
        else:
            status = "❌ FAIL"
            failed += 1
            failures.append((text, expected, actual, description))

        print(f"{status} | Expected: {expected:5} | Got: {actual:5} | {description}")
        if len(text) > 60:
            print(f"       Text: \"{text[:60]}...\"")
        else:
            print(f"       Text: \"{text}\"")
        print()

    print("=" * 80)
    print(f"TEST RESULTS: {passed} passed, {failed} failed out of {len(test_cases)} total")
    print("=" * 80)
    print()

    if failures:
        print("❌ FAILED TESTS:")
        print("-" * 80)
        for text, expected, actual, description in failures:
            print(f"Description: {description}")
            print(f"Text: \"{text}\"")
            print(f"Expected: {expected} | Got: {actual}")
            print()

    return failed == 0


if __name__ == "__main__":
    success = test_zero_leak_enforcement()
    sys.exit(0 if success else 1)
