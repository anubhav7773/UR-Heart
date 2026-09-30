# Graph Report - UR-Heart  (2026-09-30)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 3638 nodes · 5989 edges · 182 communities (175 shown, 7 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 202 edges (avg confidence: 0.92)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `116d4d55`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- User
- DateTime
- get_current_user
- ai_cluster.py
- dependencies.py
- package:flutter/material.dart
- test_production_goal_fixes.py
- themeProvider
- sanctuary_crypto_vault.dart
- profile_setup_controller.dart
- auth.py
- package:flutter_riverpod/flutter_riverpod.dart
- _
- _
- _
- auth_controller.dart
- magic_link_screen.dart
- vault_models.dart
- user_profile_model.dart
- ../../../../core/constants/app_colors.dart
- List
- growth/presentation/controllers/growth_hub_controller.dart
- chat_dialogue_controller.dart
- send_chat_message
- ConsumerState
- resonances_controller.dart
- settings_repository.dart
- static const String
- _
- _
- main.py
- persona_controller.dart
- photo_adjuster_dialog.dart
- google_auth_service.dart
- conversation_dialogue_tile.dart
- chat_models.dart
- sanctuary_navigation_shell.dart
- chat_dialogue_screen.dart
- chat_repository.dart
- auth_repository.dart
- _
- data/sanctuary_billing_service.dart
- settings_controller.dart
- ur_heart_app.dart
- ValueChanged
- whatsapp_notification_banner.dart
- web_store.py
- StatelessWidget
- sanctuary_settings_screen.dart
- _
- rewarded_ad_manager.dart
- feed_controller.dart
- neutral_dob_wheel_picker.dart
- sacred_kinship_card.dart
- atmosphere_theme_card.dart
- _
- milestone3_core_foundation_test.dart
- profile/data/profile_repository.dart
- persona_preferences_card.dart
- theme_controller.dart
- statutory_vault_controller.dart
- eva_sanctuary_screen.dart
- profile_setup/data/profile_repository.dart
- dart:io
- chats_list_controller.dart
- chat_websocket_service.dart
- data/slumber_sensor_service.dart
- vault_repository.dart
- preferences_slider_card.dart
- feed_repository.dart
- mutual_connection_tile.dart
- growth_hub_screen.dart
- vault_controller.dart
- package:flutter_test/flutter_test.dart
- test_chunk4_android_and_legal_seal.py
- _
- live_kyc_recording_modal.dart
- chat/controllers/websocket_chat_service.dart
- candidate_profile.dart
- resonance_models.dart
- milestone6_encrypted_dialogues_test.dart
- ai_sanctuary.py
- chats_list_screen.dart
- candidate_photo_carousel.dart
- ai_dialogue_coach_sheet.dart
- legal_compliance.py
- submit_grievance_dossier
- supabase_media_uploader.dart
- my_persona_screen.dart
- consent_controller.dart
- eva_controller.dart
- navigationIndexProvider
- secure_session_storage.dart
- phase5_feed_resonances_test.dart
- vault_legal_screen.dart
- milestone8_persona_vault_settings_test.dart
- grievance_dossier_modal.dart
- ai_grievance_assistant_sheet.dart
- ../../../../core/theme/theme_controller.dart
- age_gate_controller.dart
- magic_link_controller.dart
- auth_credential_field.dart
- alerts_toggle_group.dart
- candidate_profile_card.dart
- root_health_probe
- timedelta
- sanctuary_card_deck.dart
- consent_screen.dart
- ignored_profiles_controller.dart
- services/installation_service.dart
- photo_carousel_with_dots.dart
- milestone7_monetization_hub_test.dart
- manifest.json
- ws_ticket.py
- asyncio
- settings_models.dart
- rewards_models.dart
- ai_sanctuary_repository.dart
- live_video_kyc_modal.dart
- discovery_privacy_card.dart
- sovereign_control_section.dart
- dialogue_app_bar.dart
- AsyncSession
- settings_action_handlers.dart
- sacred_bridge_app_bar_action.dart
- feed_screen.dart
- rewards_controller.dart
- age_gate_auth_screen.dart
- magic_link_passage_card.dart
- dialogue_input_bar.dart
- asyncio
- feed_action_handlers.dart
- data_rights_section.dart
- nominee_designation_modal.dart
- goal_photo_adjust_and_rewards_fix_test.dart
- eva_sanctuary_test.dart
- register_underage_hardware_quarantine
- test_phase1_persistence.py
- firebase_media_uploader.dart
- google_sign_in_test.dart
- ConnectionManager
- asyncio
- package:shared_preferences/shared_preferences.dart
- incoming_like_card.dart
- flutter_windowmanager.dart
- free_ads_tab_view.dart
- resource_metrics_bar.dart
- process_web_deletion_request
- serve_data_deletion_page
- VoidCallback
- String?
- profile_setup_screen.dart
- sovereign_store_tab_view.dart
- AiFallbackService
- asyncio
- mindful_streak_card.dart
- phase4_onboarding_test.dart
- register_rotated_encryption_key
- health_check
- update_user_preferences
- record_activity
- MainActivity.kt
- StateNotifier
- app_colors.dart
- request_data_portability_export
- typedef
- ../../controllers/websocket_chat_service.dart
- ../../features/rewards/data/sanctuary_billing_service.dart
- ProfileSetupController
- @gmail
- Exception
- SanctuaryException

## God Nodes (most connected - your core abstractions)
1. `User` - 133 edges
2. `themeProvider` - 48 edges
3. `_` - 47 edges
4. `get_current_user()` - 46 edges
5. `_` - 46 edges
6. `get_db()` - 36 edges
7. `_` - 33 edges
8. `themeControllerProvider` - 31 edges
9. `_` - 27 edges
10. `Base` - 26 edges

## Surprising Connections (you probably didn't know these)
- `get_current_user()` --uses--> `User`  [INFERRED]
  backend/app/api/dependencies.py → backend/app/models/domain/user.py
- `require_superadmin()` --uses--> `User`  [INFERRED]
  backend/app/api/dependencies.py → backend/app/models/domain/user.py
- `incinerate_account_irrevocably()` --uses--> `User`  [INFERRED]
  backend/app/api/v1/endpoints/account_incinerator.py → backend/app/models/domain/user.py
- `list_pending_escalations()` --uses--> `User`  [INFERRED]
  backend/app/api/v1/endpoints/admin_kyc.py → backend/app/models/domain/user.py
- `resolve_kyc_ticket()` --uses--> `User`  [INFERRED]
  backend/app/api/v1/endpoints/admin_kyc.py → backend/app/models/domain/user.py

## Import Cycles
- None detected.

## Communities (182 total, 7 thin omitted)

### Community 0 - "User"
Cohesion: 0.04
Nodes (68): claim_ad_reward(), ClaimAdRewardRequest, get_current_streak_status(), AsyncSession, BaseModel, get, post, Credits ad reward points and swipes directly to authenticated public.users… (+60 more)

### Community 1 - "DateTime"
Cohesion: 0.07
Nodes (52): get_admob_public_keys(), process_reward_callback(), Any, Request, Verifies HMAC-SHA256 signature for non-Google networks…, Universal Cryptographic SSV Callback Handler. Rejects any spoofed, unsigned, or…, Fetches and caches Google AdMob public keys for ECDSA verification., Validates Google AdMob SSV callback. Message format: UTF-8 query string… (+44 more)

### Community 2 - "get_current_user"
Cohesion: 0.05
Nodes (55): _delete_auth_identity(), incinerate_account_irrevocably(), IncinerateAccountRequest, _purge_remote_user_storage(), AsyncSession, BaseModel, delete, DPDP ACT 2023 SECTION 12: Irrevocable Account Incinerator. Executes atomic… (+47 more)

### Community 3 - "ai_cluster.py"
Cohesion: 0.06
Nodes (56): generate_icebreakers(), polish_bio(), limit, post, Request, Generates 3 bespoke, non-intrusive dialogue starter prompts referencing shared…, Elevates user profile bio poetically without modifying factual personality…, Multimodal Liveness & Face Match via Groq Llama-3.2-11b-vision-preview. SEC-… (+48 more)

### Community 4 - "dependencies.py"
Cohesion: 0.05
Nodes (53): get_current_user(), AsyncSession, Validates Firebase Auth JWT token with cryptographic RS256 JWKS verification,…, Strict authorization gate: Validates server-side role and immutable admin…, require_superadmin(), AdminKycQueueItem, KycResolutionRequest, list_pending_escalations() (+45 more)

### Community 5 - "package:flutter/material.dart"
Cohesion: 0.05
Nodes (41): ../controllers/consent_controller.dart, ../../../core/constants/api_endpoints.dart, ../../../../core/theme/dark_sanctuary_tokens.dart, ../../../../core/theme/light_sanctuary_tokens.dart, build, _buildPortalTile, isDark, _openExternalUrl (+33 more)

### Community 6 - "test_production_goal_fixes.py"
Cohesion: 0.06
Nodes (31): AiOrchestrator, Any, Coordinates a conversational session with Eva AI, enforcing strict guardrails,…, Provides 3 mindful reply paths or coaches a user's drafted message., Empathetic legal first-responder: analyzes user's emotional description, calms…, Deep mindful fallback when remote networks are waking up or offline. Provides…, EvaGuardrails, Post-processor that strips any accidental provider names, model IDs, or… (+23 more)

### Community 7 - "themeProvider"
Cohesion: 0.08
Nodes (33): ../controllers/profile_setup_controller.dart, feed_action_handlers.dart, themeProvider, build, OutOfSwipesAdModal, userId, profileSetupControllerProvider, build (+25 more)

### Community 8 - "sanctuary_crypto_vault.dart"
Cohesion: 0.08
Nodes (23): Chacha20, _cipher, ciphertextBase64, decryptDialoguePacket, deriveSharedSecret, encryptDialogueText, EncryptedMessagePacket, exportPublicKeyBase64 (+15 more)

### Community 9 - "profile_setup_controller.dart"
Cohesion: 0.04
Nodes (48): bio, blurHashes, canCompleteSetup, completeSetup, contactBridgeHandle, contactBridgePlatform, copyWith, dobString (+40 more)

### Community 10 - "auth.py"
Cohesion: 0.08
Nodes (43): get_me(), get_users_me(), get_verification_status(), google_sync(), GoogleSyncRequest, handle_browser_magic_link_tap(), login(), LoginRequest (+35 more)

### Community 11 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.07
Nodes (39): consent_accordion_card.dart, ConsumerWidget, ../../../../core/theme/sanctuary_typography.dart, ../dark_sanctuary_tokens.dart, five_slot_photo_grid.dart, URHeartApp, themeControllerProvider, build (+31 more)

### Community 12 - "_"
Cohesion: 0.04
Nodes (45): _, accentGold, accentTerracotta, alertBanner, alertBannerBorder, background, badgeOnline, badgeWaKey (+37 more)

### Community 13 - "_"
Cohesion: 0.04
Nodes (45): _, accentGold, accentTerracotta, alertBanner, alertBannerBorder, background, badgeOnline, badgeWaKey (+37 more)

### Community 14 - "_"
Cohesion: 0.04
Nodes (49): activity_logger_service.dart, ../../../../core/services/flutter_windowmanager.dart, dart:convert, R2Uploader, uploadBinaryToR2, uploadBytesToR2, uploadTimeout, _ (+41 more)

### Community 15 - "auth_controller.dart"
Cohesion: 0.05
Nodes (41): age_gate_controller.dart, ../../data/auth_repository.dart, AuthController, authenticatedDisplayName, authenticatedPhotoUrl, authenticatedUserId, AuthState, copyWith (+33 more)

### Community 16 - "magic_link_screen.dart"
Cohesion: 0.08
Nodes (29): AppLinks, authControllerProvider, _appLinks, build, _copyMagicLink, createState, _currentStep, dispose (+21 more)

### Community 17 - "vault_models.dart"
Cohesion: 0.05
Nodes (37): age, BlockedProfile, BlockedUserProfile, category, checksumSha256, contact, copyWith, DataExportStatus (+29 more)

### Community 18 - "user_profile_model.dart"
Cohesion: 0.05
Nodes (37): age, avatarUrl, bio, boostPoints, copyWith, dateOfBirth, directLettersCount, dobVerificationPill (+29 more)

### Community 19 - "../../../../core/constants/app_colors.dart"
Cohesion: 0.06
Nodes (30): ../../../ai_sanctuary/presentation/widgets/ai_grievance_assistant_sheet.dart, ../../../../core/constants/app_colors.dart, ../../../../core/constants/app_typography.dart, ../../../legal_vault/data/vault_repository.dart, showBlockConfirmation, showReportSheet, build, ChatsMetricPill (+22 more)

### Community 20 - "List"
Cohesion: 0.06
Nodes (29): ../domain/vault_models.dart, AiIcebreakerChipsRow, build, icebreakers, isDark, build, _buildSparkItem, isDark (+21 more)

### Community 21 - "growth/presentation/controllers/growth_hub_controller.dart"
Cohesion: 0.06
Nodes (36): activeMatchContactLink, activeMatchId, advancePeerWhatsappProgress, applyReward, billing, boostPoints, copyWith, directLetters (+28 more)

### Community 22 - "chat_dialogue_controller.dart"
Cohesion: 0.06
Nodes (34): bridgeData, bridgeStage, ChatDialogueController, ChatDialogueState, _chatRepository, copyWith, currentUserId, dismissViolationAlert (+26 more)

### Community 23 - "send_chat_message"
Cohesion: 0.09
Nodes (28): BaseModel, post, Persists a new message in PostgreSQL messages table., send_chat_message(), SendMessageRequest, ChatModerationRequest, ChatModerationResponse, moderate_chat() (+20 more)

### Community 24 - "ConsumerState"
Cohesion: 0.07
Nodes (31): ConsumerState, ConsumerStatefulWidget, build, category, ConsentAccordionCard, _ConsentAccordionCardState, createState, detailedText (+23 more)

### Community 25 - "resonances_controller.dart"
Cohesion: 0.06
Nodes (32): ../controllers/resonances_controller.dart, acceptLikeAndStartChat, activeTab, copyWith, createMutualMatch, creatingMatchId, incomingLikes, isLoading (+24 more)

### Community 26 - "settings_repository.dart"
Cohesion: 0.10
Nodes (20): ../../../core/security/installation_service.dart, base64UrlEncode, buffer, chars, _dio, dioClient, getSettings, _handleDioError (+12 more)

### Community 27 - "static const String"
Cohesion: 0.07
Nodes (28): api_interceptors.dart, ../constants/api_endpoints.dart, Interceptor, ApiClient, dio, ApiInterceptors, authorizationHeaderKey, bearerPrefix (+20 more)

### Community 28 - "_"
Cohesion: 0.06
Nodes (32): _, adminKycAction, adminKycPending, adMobRewardCallback, aiKycLiveness, aiPolishBio, ApiEndpoints, appLovinRewardCallback (+24 more)

### Community 29 - "_"
Cohesion: 0.06
Nodes (31): _, clean, _cleanInvisibleChars, _convertNumberWords, _indianPhoneRegex, inspect, isValid, NlpChatSanitizer (+23 more)

### Community 30 - "main.py"
Cohesion: 0.10
Nodes (21): get_settings(), SEC-HIGH-01 Fail-Fast Mandate: If ENVIRONMENT is production, strictly assert…, Standalone validator to enforce fail-fast verification during app lifespan or…, Settings, validate_production_env(), Validates ephemeral WebSocket handshake tickets., verify_ws_ticket(), lifespan() (+13 more)

### Community 31 - "persona_controller.dart"
Cohesion: 0.07
Nodes (30): ../../../../core/media/media_compressor.dart, ../../../../core/media/supabase_media_uploader.dart, ../../../../core/services/image_moderation_service.dart, ../../data/profile_repository.dart, clearBanner, copyWith, errorMessage, isPolishing (+22 more)

### Community 32 - "photo_adjuster_dialog.dart"
Cohesion: 0.06
Nodes (30): CustomPainter, GlobalKey, GoogleLogoPainter, _applyCropAndSave, build, createState, dispose, _imageKey (+22 more)

### Community 33 - "google_auth_service.dart"
Cohesion: 0.07
Nodes (29): Completer, FirebaseAuth?, cancelled, displayName, email, errorMessage, failure, _firebaseAuth (+21 more)

### Community 34 - "conversation_dialogue_tile.dart"
Cohesion: 0.05
Nodes (34): delivery_tick_icon.dart, ../domain/chat_models.dart, ChatSeedData, getInitialConversations, getInitialMessages, getInitialSparks, ChatMessage, MessageDeliveryStatus (+26 more)

### Community 35 - "chat_models.dart"
Cohesion: 0.07
Nodes (29): age, avatarUrl, categoryTag, ChatConversation, ConversationThread, copyWith, createdAt, fromJson (+21 more)

### Community 36 - "sanctuary_navigation_shell.dart"
Cohesion: 0.08
Nodes (28): ../../../ai_sanctuary/presentation/screens/eva_sanctuary_screen.dart, ../../../chat/presentation/screens/chat_dialogue_screen.dart, ../../../chat/presentation/screens/chats_list_screen.dart, ../../../feed/presentation/screens/feed_screen.dart, apiClientProvider, _activeNotificationOverlay, _buildNavItem, createState (+20 more)

### Community 37 - "chat_dialogue_screen.dart"
Cohesion: 0.08
Nodes (28): ../../../ai_sanctuary/presentation/widgets/ai_dialogue_coach_sheet.dart, bool isOnline,, ../controllers/chat_dialogue_controller.dart, chatWebSocketServiceProvider, chatDialogueControllerProvider, build, ChatDialogueArguments, ChatDialogueScreen (+20 more)

### Community 38 - "chat_repository.dart"
Cohesion: 0.07
Nodes (28): chat_websocket_service.dart, chatMessagesProvider, chatRepositoryProvider, _conversations, conversationsProvider, _dio, dioClient, fetchActiveSparks (+20 more)

### Community 39 - "auth_repository.dart"
Cohesion: 0.07
Nodes (28): google_auth_service.dart, _apiClient, AuthRepository, authRepositoryProvider, AuthResult, cancelled, checkVerificationStatus, displayName (+20 more)

### Community 40 - "_"
Cohesion: 0.07
Nodes (29): _, accordionCategory, AppTypography, bodyMedium, bodySmall, bodyStandard, buttonPrimary, caption (+21 more)

### Community 41 - "data/sanctuary_billing_service.dart"
Cohesion: 0.07
Nodes (28): _activeTier, _dio, dispose, _fallbackProducts, fetchAvailableProducts, _handlePurchaseUpdates, _iap, _initializeBillingStream (+20 more)

### Community 42 - "settings_controller.dart"
Cohesion: 0.07
Nodes (28): clearBanner, copyWith, currentUserEmail, discreetMode, errorMessage, executePermanentAccountErasure, incinerateAccount, isIncinerating (+20 more)

### Community 43 - "ur_heart_app.dart"
Cohesion: 0.07
Nodes (27): ../constants/app_colors.dart, ../constants/app_typography.dart, ../../features/ai_sanctuary/presentation/screens/eva_sanctuary_screen.dart, ../../features/auth/presentation/screens/age_gate_auth_screen.dart, ../../features/auth/presentation/screens/consent_screen.dart, ../../features/auth/presentation/screens/magic_link_screen.dart, ../../features/chat/presentation/screens/chat_dialogue_screen.dart, ../../features/chat/presentation/screens/chats_list_screen.dart (+19 more)

### Community 44 - "ValueChanged"
Cohesion: 0.07
Nodes (24): AuthTabSwitcher, build, isDark, isSignIn, onChanged, build, ChatsSearchBar, isDark (+16 more)

### Community 45 - "whatsapp_notification_banner.dart"
Cohesion: 0.08
Nodes (25): Animation, Duration, _animController, _autoDismissTimer, avatarUrl, build, _buildAvatar, createState (+17 more)

### Community 46 - "web_store.py"
Cohesion: 0.12
Nodes (25): approve_store_order(), ApproveOrderRequest, complete_store_order(), CompleteOrderRequest, create_store_order(), CreateOrderRequest, get_store_order_status(), AsyncSession (+17 more)

### Community 47 - "StatelessWidget"
Cohesion: 0.11
Nodes (18): build, GoogleLogoIcon, GoogleSignInButton, isDark, isLoading, onPressed, paint, shouldRepaint (+10 more)

### Community 48 - "sanctuary_settings_screen.dart"
Cohesion: 0.09
Nodes (23): ../controllers/settings_controller.dart, settingsControllerProvider, build, routeName, SanctuarySettingsScreen, build, _canShred, _confirmController (+15 more)

### Community 49 - "_"
Cohesion: 0.08
Nodes (25): _, alertCrimson, alertRed, crispIvory, deepAmbientShadow, deepCharcoal, elevatedSlate, glowingTerracotta (+17 more)

### Community 50 - "rewarded_ad_manager.dart"
Cohesion: 0.08
Nodes (23): ad_reward_models.dart, _adUnitId, _adUnitIdAndroid, _adUnitIdIos, initialize, initializePreloader, instance, isAdReady (+15 more)

### Community 51 - "feed_controller.dart"
Cohesion: 0.09
Nodes (23): CandidateProfile? get, candidates, copyWith, currentCandidate, directLettersCount, dismissAdModal, errorMessage, FeedController (+15 more)

### Community 52 - "neutral_dob_wheel_picker.dart"
Cohesion: 0.09
Nodes (22): ../controllers/age_gate_controller.dart, int?, code, message, NetworkUnavailableException, ResourceNotFoundException, SanctuaryException, ServerException (+14 more)

### Community 53 - "sacred_kinship_card.dart"
Cohesion: 0.08
Nodes (22): ../../../growth/presentation/controllers/growth_hub_controller.dart, build, _buildSocialShareButton, createState, dispose, initState, isDark, _isRedeeming (+14 more)

### Community 54 - "atmosphere_theme_card.dart"
Cohesion: 0.08
Nodes (22): IconData, build, buttonText, durationTag, icon, isDark, onTap, rewardDescription (+14 more)

### Community 55 - "_"
Cohesion: 0.08
Nodes (24): _, AdMediatedNetwork, AdPlacementTypes, AdRewardEvent, AdSsvOptions, adType, build, customData (+16 more)

### Community 56 - "milestone3_core_foundation_test.dart"
Cohesion: 0.14
Nodes (13): MaterialApp, package:ur_heart/core/app/ur_heart_app.dart, package:ur_heart/core/constants/app_colors.dart, package:ur_heart/core/media/firebase_media_uploader.dart, package:ur_heart/core/network/interceptors/installation_interceptor.dart, package:ur_heart/core/services/installation_service.dart, package:ur_heart/core/services/sentry_service.dart, package:ur_heart/core/theme/light_sanctuary_tokens.dart (+5 more)

### Community 57 - "profile/data/profile_repository.dart"
Cohesion: 0.09
Nodes (21): ../../../core/services/real_gps_location_service.dart, Dio get, _apiClient, client, _currentProfile, _dio, dioClient, _emptyInitialProfile (+13 more)

### Community 58 - "persona_preferences_card.dart"
Cohesion: 0.06
Nodes (35): ../domain/user_profile_model.dart, UserPersonaModel, UserProfile, build, _buildPill, isDark, LockedCredentialsCard, profile (+27 more)

### Community 59 - "theme_controller.dart"
Cohesion: 0.10
Nodes (21): activeTheme, copyWith, hashCode, isLocked, legacyLockKey, legacyThemeKey, loadThemeFromPersistence, lockCurrentThemePermanently (+13 more)

### Community 60 - "statutory_vault_controller.dart"
Cohesion: 0.10
Nodes (21): activeExport, blockedList, blockedUsersCount, clearBanner, copyWith, designateNominee, errorMessage, exportDownloadUrl (+13 more)

### Community 61 - "eva_sanctuary_screen.dart"
Cohesion: 0.11
Nodes (20): AnimationController, ../controllers/eva_controller.dart, evaControllerProvider, animateOrb, build, _buildGlowingSanctuaryOrb, _buildMessageBubble, createState (+12 more)

### Community 62 - "profile_setup/data/profile_repository.dart"
Cohesion: 0.10
Nodes (20): ../../../core/media/r2_uploader.dart, _apiClient, fileKey, _generateEvaPolishedBio, getPresignedUploadUrl, _groqApiKey, isApproved, isPendingReview (+12 more)

### Community 63 - "dart:io"
Cohesion: 0.09
Nodes (21): dart:io, Directory, build, isDark, moments, MomentsEditorGrid, photos, package:http/testing.dart (+13 more)

### Community 64 - "chats_list_controller.dart"
Cohesion: 0.10
Nodes (20): ../../data/chat_repository.dart, ChatRepository, activeFilter, allConversations, ChatsListController, ChatsListState, copyWith, directCount (+12 more)

### Community 65 - "chat_websocket_service.dart"
Cohesion: 0.10
Nodes (20): _baseWsHost, _channel, connect, connectSecureChannel, _dio, disconnect, dispose, eventStream (+12 more)

### Community 66 - "data/slumber_sensor_service.dart"
Cohesion: 0.10
Nodes (20): _gravityThreshold, instance, _isFaceDown, _isMonitoring, _processAccelerometerData, _sensorSubscription, SlumberDeviceState, SlumberSensorService (+12 more)

### Community 67 - "vault_repository.dart"
Cohesion: 0.10
Nodes (20): _activeExport, _blockedList, blockUser, checkExportStatus, designateNominee, _dio, dioClient, downloadAndShareArchive (+12 more)

### Community 68 - "preferences_slider_card.dart"
Cohesion: 0.10
Nodes (20): _ageRange, _bioController, build, _buildFieldHeader, createState, didUpdateWidget, dispose, _eduController (+12 more)

### Community 69 - "feed_repository.dart"
Cohesion: 0.08
Nodes (23): ../../../core/error/sanctuary_exceptions.dart, ../../../core/network/dio_client.dart, Dio, ../domain/resonance_models.dart, interceptors/auth_interceptor.dart, interceptors/installation_interceptor.dart, dio, DioClient (+15 more)

### Community 70 - "mutual_connection_tile.dart"
Cohesion: 0.10
Nodes (18): ../../data/resonances_repository.dart, MutualConnection, build, IncomingLikeTile, isDark, isProcessing, like, onChatTap (+10 more)

### Community 71 - "growth_hub_screen.dart"
Cohesion: 0.12
Nodes (18): growthHubControllerProvider, build, createState, dispose, GrowthHubScreen, _GrowthHubScreenState, initState, routeName (+10 more)

### Community 72 - "vault_controller.dart"
Cohesion: 0.11
Nodes (19): VaultRepository, activeExport, blockedList, clearBanner, copyWith, designateNominee, downloadAndShareArchive, errorMessage (+11 more)

### Community 73 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.12
Nodes (14): package:flutter_test/flutter_test.dart, package:ur_heart/core/constants/api_endpoints.dart, package:ur_heart/features/auth/presentation/screens/age_gate_auth_screen.dart, package:ur_heart/features/auth/presentation/screens/consent_screen.dart, package:ur_heart/features/auth/presentation/widgets/magic_link_passage_card.dart, package:ur_heart/features/auth/presentation/widgets/statutory_links_card.dart, package:ur_heart/features/chat/presentation/screens/chat_dialogue_screen.dart, package:ur_heart/features/navigation/presentation/screens/sanctuary_navigation_shell.dart (+6 more)

### Community 74 - "test_chunk4_android_and_legal_seal.py"
Cohesion: 0.13
Nodes (18): create_mock_user(), CRITERIA 4 (SEC-MED-04): Verify that R8 isMinifyEnabled and isShrinkResources…, CRITERIA 5 (Statutory Safe Harbor): Verify Grievance Officer details (Anubhav…, CRITERIA 6 (24h SLA & 15-day resolution clock): Submitting a grievance must…, CRITERIA 7 (Pre-Storage Moderation Shield): Sending dialogue messages…, CRITERIA 8 (DPDP Act 2023 Section 12): Verify that the account incinerator…, CRITERIA 1 (SEC-HIGH-05): Inspect AndroidManifest.xml and verify that…, CRITERIA 2 (SEC-HIGH-05): Verify that SecureSessionStorage uses… (+10 more)

### Community 75 - "_"
Cohesion: 0.11
Nodes (19): blurhash_generator.dart, File, _, blurHash, byteSize, compressedFile, extractBlurHashFromBytes, fileSizeBytes (+11 more)

### Community 76 - "live_kyc_recording_modal.dart"
Cohesion: 0.12
Nodes (18): CameraController?, dioClientProvider, anchorPhotoBase64, _cameraController, _countdownTimer, createState, _dispatchRealVideoToBackend, dispose (+10 more)

### Community 77 - "chat/controllers/websocket_chat_service.dart"
Cohesion: 0.11
Nodes (18): _channel, connect, disconnect, dispose, eventStream, _heartbeatTimer, _incomingEventsController, instance (+10 more)

### Community 78 - "candidate_profile.dart"
Cohesion: 0.11
Nodes (18): age, blurHashes, checkOrientationShield, copyWith, distanceKm, fromJson, fullName, gender (+10 more)

### Community 79 - "resonance_models.dart"
Cohesion: 0.11
Nodes (18): age, blurHash, fromJson, fullName, hasUnreadMessages, id, IncomingLike, IncomingLikeProfile (+10 more)

### Community 80 - "milestone6_encrypted_dialogues_test.dart"
Cohesion: 0.12
Nodes (16): package:ur_heart/core/theme/theme_controller.dart, package:ur_heart/features/chat/controllers/websocket_chat_service.dart, package:ur_heart/features/chat/data/chat_websocket_service.dart, package:ur_heart/features/chat/domain/chat_models.dart, package:ur_heart/features/chat/domain/nlp_chat_sanitizer.dart, package:ur_heart/features/chat/presentation/screens/chats_list_screen.dart, package:ur_heart/features/chat/presentation/widgets/ai_icebreaker_chips_row.dart, package:ur_heart/features/chat/presentation/widgets/conversation_dialogue_tile.dart (+8 more)

### Community 81 - "ai_sanctuary.py"
Cohesion: 0.23
Nodes (17): assist_grievance_filing(), chat_with_eva(), DialogueCoachRequest, EvaChatRequest, EvaChatResponse, FeedbackRequest, get_dialogue_coaching(), GrievanceAssistRequest (+9 more)

### Community 82 - "chats_list_screen.dart"
Cohesion: 0.12
Nodes (17): chat_dialogue_screen.dart, ../controllers/chats_list_controller.dart, chatsListControllerProvider, build, _buildEmptyState, _buildFilterMenuItem, _buildSheetOption, ChatsListScreen (+9 more)

### Community 83 - "candidate_photo_carousel.dart"
Cohesion: 0.12
Nodes (19): SanctuaryAppGateway, _SanctuaryAppGatewayState, blurHashes, build, CandidatePhotoCarousel, _CandidatePhotoCarouselState, createState, _currentIndex (+11 more)

### Community 84 - "ai_dialogue_coach_sheet.dart"
Cohesion: 0.12
Nodes (17): aiSanctuaryRepositoryProvider, _adviceResult, AiDialogueCoachSheet, _AiDialogueCoachSheetState, build, createState, dispose, _draftController (+9 more)

### Community 85 - "legal_compliance.py"
Cohesion: 0.24
Nodes (13): check_export_status(), _compile_user_export_bundle(), UUID, Retrieves status and payload of completed data portability archive., Asynchronously extracts all user records, hashes payload, and stores encrypted…, BlockedUser, ConsentAuditLog, DataExportRequest (+5 more)

### Community 86 - "submit_grievance_dossier"
Cohesion: 0.13
Nodes (11): block_user(), BlockUserRequest, GrievancePayload, NomineePayload, BaseModel, post, DPDP Act 2023 Section 14: Designates trusted nominee for account governance., IT Rules 2021 Rule 3(2): Formal grievance filing. Emits formal 24h statutory… (+3 more)

### Community 87 - "supabase_media_uploader.dart"
Cohesion: 0.20
Nodes (9): Client?, anonKey, bucketName, _customClient, getPublicUrl, setClientForTesting, SupabaseMediaUploader, supabaseUrl (+1 more)

### Community 88 - "my_persona_screen.dart"
Cohesion: 0.12
Nodes (16): ../controllers/persona_controller.dart, personaControllerProvider, _adjustExistingPhoto, build, MyPersonaScreen, _pickAndProcessPhoto, routeName, _showPhotoUploadModal (+8 more)

### Community 89 - "consent_controller.dart"
Cohesion: 0.12
Nodes (16): int get, canProceed, ConsentController, ConsentState, copyWith, hashCode, isAgeConfirmed, isDpdpConsented (+8 more)

### Community 90 - "eva_controller.dart"
Cohesion: 0.12
Nodes (16): AiSanctuaryRepository, activePartner, activePartnerName, activeScreen, clearSession, copyWith, EvaController, EvaState (+8 more)

### Community 91 - "navigationIndexProvider"
Cohesion: 0.14
Nodes (15): build, isDark, onWatchAdTriggered, OutOfSwipesModal, build, initState, navigationIndexProvider, activeIndex (+7 more)

### Community 92 - "secure_session_storage.dart"
Cohesion: 0.08
Nodes (23): FlutterSecureStorage, _androidOptions, clearAllSessionData, getAuthToken, getUserEmail, getUserRole, instance, isProfileSetupCompleted (+15 more)

### Community 93 - "phase5_feed_resonances_test.dart"
Cohesion: 0.17
Nodes (15): package:ur_heart/features/feed/data/feed_repository.dart, package:ur_heart/features/feed/presentation/controllers/feed_controller.dart, package:ur_heart/features/feed/presentation/controllers/ignored_profiles_controller.dart, package:ur_heart/features/feed/presentation/screens/feed_screen.dart, package:ur_heart/features/feed/presentation/screens/ignored_profiles_screen.dart, package:ur_heart/features/feed/presentation/widgets/candidate_photo_carousel.dart, package:ur_heart/features/feed/presentation/widgets/candidate_profile_card.dart, package:ur_heart/features/feed/presentation/widgets/out_of_swipes_ad_modal.dart (+7 more)

### Community 94 - "vault_legal_screen.dart"
Cohesion: 0.13
Nodes (15): ../controllers/vault_controller.dart, vaultControllerProvider, build, _openBlockedList, _openGrievanceModal, _openNomineeModal, _openTrackGrievanceModal, routeName (+7 more)

### Community 95 - "milestone8_persona_vault_settings_test.dart"
Cohesion: 0.19
Nodes (13): package:ur_heart/features/legal_vault/data/vault_repository.dart, package:ur_heart/features/legal_vault/presentation/screens/vault_legal_screen.dart, package:ur_heart/features/profile/data/profile_repository.dart, package:ur_heart/features/profile/presentation/screens/my_persona_screen.dart, package:ur_heart/features/settings/data/settings_repository.dart, package:ur_heart/features/settings/presentation/screens/sanctuary_settings_screen.dart, package:ur_heart/features/settings/presentation/widgets/superadmin_sentinel_tile.dart, createTestApp (+5 more)

### Community 96 - "grievance_dossier_modal.dart"
Cohesion: 0.10
Nodes (20): ../../data/vault_repository.dart, ChatSafetyDialog, vaultRepositoryProvider, build, _categories, _category, createState, dispose (+12 more)

### Community 97 - "ai_grievance_assistant_sheet.dart"
Cohesion: 0.14
Nodes (14): class, ../../data/ai_sanctuary_repository.dart, AiGrievanceAssistantSheet, _AiGrievanceAssistantSheetState, build, createState, dispose, _guidance (+6 more)

### Community 98 - "../../../../core/theme/theme_controller.dart"
Cohesion: 0.14
Nodes (13): ../controllers/auth_controller.dart, ../controllers/ignored_profiles_controller.dart, ../../../../core/theme/theme_controller.dart, build, _buildDropdownContainer, _months, NeutralDobWheel, build (+5 more)

### Community 99 - "age_gate_controller.dart"
Cohesion: 0.14
Nodes (14): AgeGateController, AgeGateState, birthDate, calculatedAge, checkQuarantine, clearQuarantine, copyWith, evaluateDob (+6 more)

### Community 100 - "magic_link_controller.dart"
Cohesion: 0.14
Nodes (14): canResend, cooldownSeconds, copyWith, deepLinkError, dispose, handleDeepLinkUrl, isVerified, isVerifying (+6 more)

### Community 101 - "auth_credential_field.dart"
Cohesion: 0.07
Nodes (27): Color, AuthCredentialField, build, hintText, inputBg, inputBorder, keyboardType, label (+19 more)

### Community 102 - "alerts_toggle_group.dart"
Cohesion: 0.13
Nodes (14): AlertsToggleGroup, build, _buildToggle, discreetMode, isDark, masterPush, nightSlumber, onDiscreetChanged (+6 more)

### Community 103 - "candidate_profile_card.dart"
Cohesion: 0.15
Nodes (13): ai_resonance_insight_box.dart, dart:math, build, candidate, CandidateProfileCard, _CandidateProfileCardState, _completeSwipe, createState (+5 more)

### Community 104 - "root_health_probe"
Cohesion: 0.14
Nodes (13): live_render_request_logger(), api_route, limit, Request, SanctuaryException, Guarantees every single request, path, method, and client IP is immediately…, Root endpoint: - If accessed by a web browser (accept: text/html) on '/',…, root_health_probe() (+5 more)

### Community 105 - "timedelta"
Cohesion: 0.20
Nodes (14): asyncio, Test 3: DPDP Sec 11 Data Portability Archive Test (SEC-09 Test) Initiates…, Test 4: IT Rules 2021 Grievance Dossier Filing Test (SEC-09 Test) Logs…, Test 5: DPDP Act 2023 Sec 14 Data Nominee Designation, Test 1: Irrevocable Account Incineration Verification (SEC-06 Test) Valid ERASE…, Test 2: Hardware Underage Quarantine Bypass Test (SEC-08 Test) Underage input…, test_sec06_account_incinerator_atomic_wipe(), test_sec08_underage_quarantine_engine() (+6 more)

### Community 106 - "sanctuary_card_deck.dart"
Cohesion: 0.15
Nodes (13): candidate_photo_carousel.dart, CandidateProfile, build, createState, _dragOffset, isDark, onSwipeLeft, onSwipeRight (+5 more)

### Community 107 - "consent_screen.dart"
Cohesion: 0.16
Nodes (13): ../../../../core/theme/widgets/theme_selector_pill.dart, consentProvider, build, _buildFooterLink, ConsentScreen, _ConsentScreenState, createState, initState (+5 more)

### Community 108 - "ignored_profiles_controller.dart"
Cohesion: 0.15
Nodes (13): feed_controller.dart, copyWith, IgnoredProfilesController, IgnoredProfilesState, isLoading, passedProfiles, _ref, repo (+5 more)

### Community 109 - "services/installation_service.dart"
Cohesion: 0.14
Nodes (13): _cachedUuid, clearInstallationData, clearMemoryCache, getInstallationUuid, getOrCreateInstallationUuid, InstallationService, instance, legacyUuidKey (+5 more)

### Community 110 - "photo_carousel_with_dots.dart"
Cohesion: 0.15
Nodes (13): blurHashes, build, _buildFallback, createState, _currentIndex, dispose, isDark, isKycVerified (+5 more)

### Community 111 - "milestone7_monetization_hub_test.dart"
Cohesion: 0.18
Nodes (12): package:ur_heart/core/ads/rewarded_ad_manager.dart, package:ur_heart/core/billing/sanctuary_billing_service.dart, package:ur_heart/features/rewards/domain/rewards_models.dart, package:ur_heart/features/rewards/presentation/controllers/growth_hub_controller.dart, package:ur_heart/features/rewards/presentation/controllers/rewards_controller.dart, package:ur_heart/features/rewards/presentation/screens/growth_hub_screen.dart, package:ur_heart/features/rewards/presentation/services/slumber_sensor_service.dart, package:ur_heart/features/rewards/presentation/widgets/enclave_reveal_modal.dart (+4 more)

### Community 112 - "manifest.json"
Cohesion: 0.14
Nodes (13): appIcon, height, localPathAssets, localPathScreens, previewHtml, screenId, width, darkCount (+5 more)

### Community 113 - "ws_ticket.py"
Cohesion: 0.22
Nodes (11): websocket, Production WSS endpoint authenticated strictly via single-use ephemeral ticket.…, secure_chat_websocket_endpoint(), _cleanup_expired_tickets(), generate_ephemeral_websocket_ticket(), post, UUID, Issues a cryptographically random, single-use, 60-second ticket for WSS… (+3 more)

### Community 114 - "asyncio"
Cohesion: 0.15
Nodes (13): asyncio, Test 3: Night Slumber Mode Sync (DIS-13 Fix) Tests PATCH…, Test 4: X25519 Public Key Registration (DIS-05 Fix) Tests POST…, Test 5: Nominee Flexible Schema (DIS-10 Fix) Tests POST /api/v1/vault/nominee…, Test 6: Grievance Flexible Schema (DIS-11 Fix) Tests POST…, Test 1: Profile Update Persistence (DIS-03 & DUM-17 Fix) Tests PUT…, Test 2: User Preferences Update (DIS-04 Fix) Tests PUT /api/v1/user/preferences…, test_dis03_profile_update_and_get() (+5 more)

### Community 115 - "settings_models.dart"
Cohesion: 0.15
Nodes (12): activeKeyFingerprint, copyWith, discreetMode, isIncognito, masterResonance, nightSanctuarySlumber, pushNotificationsEnabled, SanctuarySettings (+4 more)

### Community 116 - "rewards_models.dart"
Cohesion: 0.15
Nodes (12): bool get, activeMatchId, activeMatchName, copyWith, directLettersCount, ephemeralWhatsappLink, isSlumberActive, isWhatsappUnlocked (+4 more)

### Community 117 - "ai_sanctuary_repository.dart"
Cohesion: 0.15
Nodes (12): ../../../core/network/api_client.dart, apiClient, assistGrievanceFiling, chatWithEva, content, EvaMessage, _generateContextualReply, getDialogueCoaching (+4 more)

### Community 118 - "live_video_kyc_modal.dart"
Cohesion: 0.17
Nodes (12): dart:async, build, _countdownSeconds, createState, dispose, _isProcessing, _isRecording, LiveVideoKycModal (+4 more)

### Community 119 - "discovery_privacy_card.dart"
Cohesion: 0.15
Nodes (12): bool?, ../domain/settings_models.dart, build, DiscoveryPrivacyCard, isDark, isIncognito, isRotatingKey, onIncognitoChanged (+4 more)

### Community 120 - "sovereign_control_section.dart"
Cohesion: 0.25
Nodes (7): irrevocable_erasure_modal.dart, build, isDark, isIncinerating, onConfirmErasure, onLogOut, SovereignControlSection

### Community 121 - "dialogue_app_bar.dart"
Cohesion: 0.15
Nodes (12): build, _buildAvatar, DialogueAppBar, hasWaKey, isDark, isOnline, onBack, preferredSize (+4 more)

### Community 122 - "AsyncSession"
Cohesion: 0.21
Nodes (12): fetch_designated_nominee(), get_blocked_users(), get_my_grievances(), AsyncSession, delete, get, Returns list of statutory grievances filed by current user for IT Rules 2021…, Statutory tracking endpoint for any grievance dossier by reference ID. (+4 more)

### Community 123 - "settings_action_handlers.dart"
Cohesion: 0.15
Nodes (11): ../../../core/crypto/sanctuary_crypto_vault.dart, ../../data/settings_repository.dart, ../../../growth/data/slumber_sensor_service.dart, settingsRepositoryProvider, handleAccountIncineration, handleKeyRotation, handlePreferencesToggle, handleReferralShare (+3 more)

### Community 124 - "sacred_bridge_app_bar_action.dart"
Cohesion: 0.17
Nodes (11): ../../data/chat_websocket_service.dart, ChatWebSocketService, bridgeData, build, isDark, _launchSacredBridgeIntent, matchId, SacredBridgeAppBarAction (+3 more)

### Community 125 - "feed_screen.dart"
Cohesion: 0.18
Nodes (11): ../domain/candidate_profile.dart, feedControllerProvider, build, FeedScreen, _openDirectLetterModal, routeName, _showOutOfSwipes, Route /ignored (+3 more)

### Community 126 - "rewards_controller.dart"
Cohesion: 0.17
Nodes (11): ../../domain/rewards_models.dart, advancePeerWhatsappProgress, applyReward, keyLetters, keyPeerWaProgress, keySlumber, keySwipes, keyWaProgress (+3 more)

### Community 127 - "age_gate_auth_screen.dart"
Cohesion: 0.17
Nodes (11): AgeGateAuthScreen, build, routeName, ../../../profile_setup/presentation/controllers/profile_setup_controller.dart, Route /profile-setup, Route /verify-email, ../widgets/auth_credential_field.dart, ../widgets/auth_tab_switcher.dart (+3 more)

### Community 128 - "magic_link_passage_card.dart"
Cohesion: 0.17
Nodes (11): build, _buildStepRow, currentStep, elapsedSeconds, _formatElapsed, MagicLinkPassageCard, onCopyLink, onOpenDirectLink (+3 more)

### Community 129 - "dialogue_input_bar.dart"
Cohesion: 0.18
Nodes (11): build, _canSend, _controller, createState, DialogueInputBar, _DialogueInputBarState, dispose, _handleSend (+3 more)

### Community 130 - "asyncio"
Cohesion: 0.18
Nodes (11): asyncio, Test 3: WSS Ephemeral Ticket Single-Use Replay Test (SEC-13 Test) Ticket…, Test 5: HTTP Security Headers Audit (Checklist Points 18 & 19) Verifies HSTS,…, Test 4: Gateway Rate Limiting Assertion (SEC-15 Test) Verifies that requests…, Test 1b: Bio Polish Endpoint Prompt Injection Defense (SEC-11 Integration Test), Test 2: AI Vision Failure Fail-Closed Test (SEC-11 Test) Corrupted frames…, test_sec11_ai_vision_fail_closed_kyc(), test_sec11_prompt_injection_endpoint() (+3 more)

### Community 131 - "feed_action_handlers.dart"
Cohesion: 0.18
Nodes (10): ../controllers/feed_controller.dart, ../../../../core/ads/rewarded_ad_manager.dart, ../../data/feed_repository.dart, ../../../legal_vault/presentation/widgets/grievance_dossier_modal.dart, feedRepositoryProvider, FeedActionHandlers, handleOutOfSwipesReward, handlePassRewind (+2 more)

### Community 132 - "data_rights_section.dart"
Cohesion: 0.18
Nodes (10): DataNominee, DataExportRecord, activeExport, build, DataRightsSection, isDark, isExporting, nominee (+2 more)

### Community 133 - "nominee_designation_modal.dart"
Cohesion: 0.20
Nodes (10): build, _contactController, createState, dispose, isDark, _nameController, NomineeDesignationModal, _NomineeDesignationModalState (+2 more)

### Community 134 - "goal_photo_adjust_and_rewards_fix_test.dart"
Cohesion: 0.18
Nodes (10): package:image/image.dart, package:ur_heart/core/ads/ad_reward_models.dart, package:ur_heart/features/growth/presentation/controllers/growth_hub_controller.dart, package:ur_heart/features/profile/domain/user_profile_model.dart, package:ur_heart/features/profile/presentation/widgets/moments_media_grid.dart, package:ur_heart/features/profile/presentation/widgets/photo_adjuster_dialog.dart, package:ur_heart/features/rewards/presentation/widgets/mindful_streak_card.dart, package:ur_heart/features/rewards/presentation/widgets/resource_metrics_bar.dart (+2 more)

### Community 135 - "eva_sanctuary_test.dart"
Cohesion: 0.18
Nodes (10): package:ur_heart/core/network/api_client.dart, package:ur_heart/features/ai_sanctuary/data/ai_sanctuary_repository.dart, package:ur_heart/features/ai_sanctuary/presentation/screens/eva_sanctuary_screen.dart, package:ur_heart/features/ai_sanctuary/presentation/widgets/ai_dialogue_coach_sheet.dart, package:ur_heart/features/ai_sanctuary/presentation/widgets/ai_grievance_assistant_sheet.dart, assistGrievanceFiling, chatWithEva, getDialogueCoaching (+2 more)

### Community 136 - "register_underage_hardware_quarantine"
Cohesion: 0.22
Nodes (10): AsyncSession, BaseModel, get, post, Request, QuarantineRegistrationPayload, DPDP ACT 2023 SECTION 9: Anti-Bypass Hardware Quarantine. Locks device…, Called on app launch to intercept blacklisted hardware even after storage wipes. (+2 more)

### Community 137 - "test_phase1_persistence.py"
Cohesion: 0.24
Nodes (8): asyncio, Superadmin Security Gate Test: Ensures that authenticated users WITHOUT…, Exit Criteria 4: Ad Idempotency Test. Same transaction_id hit twice; second…, test_ad_ssv_idempotency_workflow(), test_admin_kyc_security_check(), mock_db_session(), mock_phase1_user(), fixture

### Community 138 - "firebase_media_uploader.dart"
Cohesion: 0.12
Nodes (15): dart:typed_data, _, BlurhashGenerator, fallbackHash, generateBlurHash, _customStorage, FirebaseMediaUploader, setStorageInstanceForTesting (+7 more)

### Community 139 - "google_sign_in_test.dart"
Cohesion: 0.18
Nodes (10): package:ur_heart/features/auth/data/auth_repository.dart, package:ur_heart/features/auth/data/google_auth_service.dart, package:ur_heart/features/auth/presentation/controllers/age_gate_controller.dart, package:ur_heart/features/auth/presentation/controllers/auth_controller.dart, package:ur_heart/features/auth/presentation/widgets/google_sign_in_button.dart, main, mockError, shouldCancel (+2 more)

### Community 140 - "ConnectionManager"
Cohesion: 0.28
Nodes (4): ConnectionManager, Any, WebSocket, In-memory active WebSocket connection manager.

### Community 141 - "asyncio"
Cohesion: 0.22
Nodes (9): asyncio, Verifies Razorpay Webhook HMAC-SHA256 signature enforcement on raw body bytes., Test 1: Fake Ad Reward Callback Rejection (SEC-04 Test) An unauthenticated /…, Test 2: Spoofed RevenueCat Lifetime Upgrade Rejection (SEC-05 Test) Calling…, Test 4: Subscription Cancellation Auto-Revert Test Simulating a CANCELLATION or…, test_sec04_fake_ad_reward_callback_rejection(), test_sec05_razorpay_hmac_verification(), test_sec05_spoofed_revenuecat_webhook_rejection() (+1 more)

### Community 142 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.12
Nodes (14): core/app/ur_heart_app.dart, core/services/activity_logger_service.dart, core/storage/secure_session_storage.dart, defaultDsn, initialize, SentryService, tracesSampleRate, main (+6 more)

### Community 143 - "incoming_like_card.dart"
Cohesion: 0.22
Nodes (8): dart:ui, build, _buildFallback, IncomingLikeCard, isDark, isSovereignUser, likeData, onChatTriggered

### Community 144 - "flutter_windowmanager.dart"
Cohesion: 0.22
Nodes (8): addFlags, _channel, clearFlags, FLAG_SECURE, FlutterWindowManager, package:flutter/services.dart, static const int, static const MethodChannel

### Community 145 - "free_ads_tab_view.dart"
Cohesion: 0.22
Nodes (8): FreeAdsTabView, isDark, userId, mindful_streak_card.dart, night_slumber_toggle_card.dart, rewarded_placement_tile.dart, sacred_kinship_card.dart, zero_paywall_banner.dart

### Community 146 - "resource_metrics_bar.dart"
Cohesion: 0.22
Nodes (8): build, _buildPill, directLetters, isAdFree, isDark, ResourceMetricsBar, revealTokens, swipesRemaining

### Community 147 - "process_web_deletion_request"
Cohesion: 0.25
Nodes (7): process_web_deletion_request(), AsyncSession, BaseModel, post, Processes web deletion request from Google Play public deletion page. Deletes…, WebDeletionRequest, field_validator

### Community 148 - "serve_data_deletion_page"
Cohesion: 0.32
Nodes (8): get, Request, Statutory Privacy Policy compliant with: - Digital Personal Data Protection…, Terms of Service & EULA with Section 79 IT Act Intermediary Safe Harbor., Mandatory Google Play Data Deletion Request Page. Enables users to submit an…, serve_data_deletion_page(), serve_privacy_policy(), serve_terms_of_service()

### Community 149 - "VoidCallback"
Cohesion: 0.07
Nodes (23): ../../domain/nlp_chat_sanitizer.dart, onResend, SanitizationResult, bridgeStage, build, ChatDetailActionBar, isDark, onSendMedia (+15 more)

### Community 150 - "String?"
Cohesion: 0.25
Nodes (7): bio, build, intentQuote, interestTags, isDark, MindfulIntentCard, String?

### Community 151 - "profile_setup_screen.dart"
Cohesion: 0.18
Nodes (11): createState, dispose, _nameController, ProfileSetupScreen, _ProfileSetupScreenState, routeName, ../widgets/five_slot_photo_grid.dart, ../widgets/live_kyc_recording_modal.dart (+3 more)

### Community 152 - "sovereign_store_tab_view.dart"
Cohesion: 0.25
Nodes (7): build, _buildMicroPackRow, _buildSubscriptionTile, isDark, _showCheckoutModal, SovereignStoreTabView, storeWebUrl

### Community 153 - "AiFallbackService"
Cohesion: 0.43
Nodes (4): AiFallbackService, Any, Executes fallback chat completion via OpenRouter Free Tier., Executes multimodal vision failover using OpenRouter free vision model.

### Community 154 - "asyncio"
Cohesion: 0.29
Nodes (7): asyncio, Duplicate transaction ID returns verified status without re-executing ledger…, Test 2: Spoofed Client Receipt Rejection (DIS-01 Test) Bina store authority ke…, Valid Google Play purchase token grants tier, sets ad-free, and records ledger…, test_idempotent_duplicate_transaction(), test_spoofed_client_receipt_rejection(), test_valid_store_receipt_verification_and_entitlement()

### Community 155 - "mindful_streak_card.dart"
Cohesion: 0.29
Nodes (6): ../controllers/growth_hub_controller.dart, ../../../../core/ads/ad_reward_models.dart, build, _formatSeconds, isDark, userId

### Community 156 - "phase4_onboarding_test.dart"
Cohesion: 0.25
Nodes (7): ElevatedButton, package:ur_heart/features/auth/presentation/widgets/neutral_dob_wheel.dart, package:ur_heart/features/profile_setup/presentation/controllers/profile_setup_controller.dart, package:ur_heart/features/profile_setup/presentation/screens/profile_setup_screen.dart, package:ur_heart/features/profile_setup/presentation/widgets/five_slot_photo_grid.dart, package:ur_heart/features/profile_setup/presentation/widgets/live_kyc_recording_modal.dart, main

### Community 157 - "register_rotated_encryption_key"
Cohesion: 0.33
Nodes (6): KeyRotationRequest, AsyncSession, BaseModel, post, DIS-05 Fix: Stores the user's authentic X25519 public key in Supabase. Allows…, register_rotated_encryption_key()

### Community 158 - "health_check"
Cohesion: 0.33
Nodes (6): health_check(), api_route, limit, Request, Handles UptimeRobot 5-minute HEAD ping. Returns zero body on HEAD to save…, Response

### Community 159 - "update_user_preferences"
Cohesion: 0.33
Nodes (6): PreferencesUpdateRequest, AsyncSession, BaseModel, put, DIS-04 Fix: Persists Ghost Cloak incognito, discreet lock-screen notifications,…, update_user_preferences()

### Community 160 - "record_activity"
Cohesion: 0.33
Nodes (6): ActivityLogPayload, BaseModel, post, Request, Real-Time Render Activity Telemetry Stream. Instantly outputs structured log to…, record_activity()

### Community 162 - "MainActivity.kt"
Cohesion: 0.60
Nodes (3): MainActivity, FlutterActivity, FlutterEngine

### Community 163 - "StateNotifier"
Cohesion: 0.40
Nodes (5): ThemeController, ThemeState, RewardHubState, RewardsController, StateNotifier

### Community 164 - "app_colors.dart"
Cohesion: 0.50
Nodes (3): ../theme/dark_sanctuary_tokens.dart, ../theme/light_sanctuary_tokens.dart, ../theme/sanctuary_colors.dart

### Community 165 - "request_data_portability_export"
Cohesion: 0.67
Nodes (3): DPDP Act 2023 Section 11: Generates an exportable, tamper-proof JSON bundle of…, request_data_portability_export(), BackgroundTasks

## Knowledge Gaps
- **1866 isolated node(s):** `canResend`, `cooldownSeconds`, `copyWith`, `deepLinkError`, `dispose` (+1861 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `User` connect `User` to `DateTime`, `get_current_user`, `ai_cluster.py`, `dependencies.py`, `test_production_goal_fixes.py`, `test_phase1_persistence.py`, `auth.py`, `process_web_deletion_request`, `send_chat_message`, `register_rotated_encryption_key`, `main.py`, `update_user_preferences`, `request_data_portability_export`, `web_store.py`, `test_chunk4_android_and_legal_seal.py`, `ai_sanctuary.py`, `legal_compliance.py`, `submit_grievance_dossier`, `ws_ticket.py`, `AsyncSession`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **Why does `_` connect `_` to `_`, `_`, `package:flutter/material.dart`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Why does `InAppPurchase` connect `DateTime` to `data/sanctuary_billing_service.dart`, `get_current_user`, `ai_cluster.py`, `web_store.py`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Are the 72 inferred relationships involving `User` (e.g. with `get_current_user()` and `require_superadmin()`) actually correct?**
  _`User` has 72 INFERRED edges - model-reasoned connections that need verification._
- **What connects `canResend`, `cooldownSeconds`, `copyWith` to the rest of the system?**
  _1866 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `User` be split into smaller, more focused modules?**
  _Cohesion score 0.04495504495504495 - nodes in this community are weakly interconnected._
- **Should `DateTime` be split into smaller, more focused modules?**
  _Cohesion score 0.07077625570776255 - nodes in this community are weakly interconnected._