import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Resolves an avatar or photo path into an appropriate Flutter ImageProvider.
/// Supports:
/// - Remote HTTPS/HTTP URLs and Web Blob URLs (NetworkImage)
/// - Base64 Data URIs (MemoryImage)
/// - Local File system paths on Mobile/Desktop (/data/..., C:\..., file://...) (FileImage)
/// - Flutter Asset bundle paths (AssetImage)
ImageProvider? resolveSanctuaryImageProvider(String? rawPath) {
  if (rawPath == null) return null;
  var path = rawPath.trim();
  if (path.isEmpty) return null;

  if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:')) {
    return NetworkImage(path);
  }

  if (path.startsWith('data:image/') && path.contains(',')) {
    try {
      final bytes = base64Decode(path.split(',').last);
      return MemoryImage(bytes);
    } catch (_) {}
  }

  if (path.startsWith('assets/')) {
    return AssetImage(path);
  }

  if (!kIsWeb) {
    if (path.startsWith('file://')) {
      path = path.replaceFirst('file://', '');
    }

    try {
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {}
  }

  return null;
}

/// Checks whether the provided avatar path represents a resolvable image.
bool hasValidSanctuaryImage(String? rawPath) {
  return resolveSanctuaryImageProvider(rawPath) != null;
}
