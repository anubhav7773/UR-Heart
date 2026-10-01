import 'dart:io';
import 'package:flutter/material.dart';

/// Resolves an avatar or photo path into an appropriate Flutter ImageProvider.
/// Supports:
/// - Remote HTTPS/HTTP URLs (NetworkImage)
/// - Local File system paths (/data/..., C:\..., file://...) (FileImage)
/// - Flutter Asset bundle paths (AssetImage)
ImageProvider? resolveSanctuaryImageProvider(String? rawPath) {
  if (rawPath == null) return null;
  var path = rawPath.trim();
  if (path.isEmpty) return null;

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }

  if (path.startsWith('file://')) {
    path = path.replaceFirst('file://', '');
  }

  try {
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
  } catch (_) {}

  if (path.startsWith('assets/')) {
    return AssetImage(path);
  }

  return null;
}

/// Checks whether the provided avatar path represents a resolvable image.
bool hasValidSanctuaryImage(String? rawPath) {
  return resolveSanctuaryImageProvider(rawPath) != null;
}
