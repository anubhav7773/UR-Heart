import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/media_compressor.dart';

class ManagePhotosScreen extends StatefulWidget {
  const ManagePhotosScreen({super.key});

  @override
  State<ManagePhotosScreen> createState() => _ManagePhotosScreenState();
}

class _ManagePhotosScreenState extends State<ManagePhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  Map<int, Map<String, dynamic>> _slots = {}; // slot_index -> {photo_url, blur_hash}

  @override
  void initState() {
    super.initState();
    _fetchUserPhotos();
  }

  Future<void> _fetchUserPhotos() async {
    setState(() => _isLoading = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = createApiClient();
      final response = await dio.get(
        '/api/v1/users/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final List photos = response.data['photos'] ?? [];
        final Map<int, Map<String, dynamic>> loadedSlots = {};
        for (var p in photos) {
          loadedSlots[p['slot_index']] = {
            'photo_url': p['photo_url'],
            'blur_hash': p['blur_hash'] ?? 'LEHLh[WB2yk8pyoJadR*.7kCMdnj',
          };
        }
        setState(() => _slots = loadedSlots);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto(int slotIndex) async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Optimizing & running anti-leak check..."), duration: Duration(seconds: 1)),
    );

    try {
      final compressed = await MediaCompressor.compressProfilePhoto(File(file.path));

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = createApiClient();

      // Step 1: Anti-leak moderation scan
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(compressed.bytes, filename: "slot_$slotIndex.webp"),
      });

      final scanRes = await dio.post(
        '/api/v1/moderation/scan-photo?require_face=${slotIndex == 1}',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (scanRes.statusCode != 200) {
        throw Exception("Photo rejected by moderation filters.");
      }

      // Step 2: Upload to user photos repository
      final uploadData = FormData.fromMap({
        'slot_index': slotIndex,
        'blur_hash': compressed.blurHash,
        'file': MultipartFile.fromBytes(compressed.bytes, filename: "slot_$slotIndex.webp"),
      });

      await dio.post(
        '/api/v1/user/photos/upload',
        data: uploadData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      await _fetchUserPhotos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✓ Photo updated successfully!"), backgroundColor: Color(0xFF06D6A0)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: const Color(0xFFFF334B)),
        );
      }
    }
  }

  Future<void> _deletePhoto(int slotIndex) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = createApiClient();
      await dio.delete(
        '/api/v1/user/photos/$slotIndex',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      setState(() => _slots.remove(slotIndex));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo removed."), backgroundColor: Color(0xFF06D6A0)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not delete: $e"), backgroundColor: const Color(0xFFFF334B)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color canvasBg = Color(0xFF0A0A0D);
    const Color cardSurface = Color(0xFF16161D);
    const Color brandPrimary = Color(0xFFFF2E63);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        elevation: 0,
        title: const Text("Manage Profile Photos", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandPrimary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF08D9D6), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Slot 1 is your public discovery avatar. Photos are protected by FLAG_SECURE and scanned for contact-sharing violations.",
                          style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Hero Slot 1
                const Text("Slot 1 (Hero Display Photo)", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildPhotoTile(1, isHero: true),
                const SizedBox(height: 24),

                // Secondary Slots 2 - 5
                const Text("Lifestyle Photos (Slots 2 to 5)", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                  children: [
                    _buildPhotoTile(2),
                    _buildPhotoTile(3),
                    _buildPhotoTile(4),
                    _buildPhotoTile(5),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildPhotoTile(int slotIndex, {bool isHero = false}) {
    final photoData = _slots[slotIndex];
    final bool hasPhoto = photoData != null;
    const Color cardSurface = Color(0xFF16161D);
    const Color brandPrimary = Color(0xFFFF2E63);

    return Container(
      height: isHero ? 200 : null,
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHero ? brandPrimary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
          width: isHero ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: hasPhoto
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: photoData['photo_url'],
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => BlurHash(hash: photoData['blur_hash']),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), shape: BoxShape.circle),
                      child: IconButton(
                        icon: Icon(
                          isHero ? Icons.edit : Icons.delete_outline,
                          color: isHero ? Colors.white : const Color(0xFFFF334B),
                          size: 18,
                        ),
                        onPressed: () => isHero ? _pickAndUploadPhoto(slotIndex) : _deletePhoto(slotIndex),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        isHero ? "Primary Avatar" : "Slot #$slotIndex",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            : InkWell(
                onTap: () => _pickAndUploadPhoto(slotIndex),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_outlined, color: Color(0xFFA0A0B2), size: 28),
                      const SizedBox(height: 6),
                      Text("Add Slot #$slotIndex", style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 12)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
