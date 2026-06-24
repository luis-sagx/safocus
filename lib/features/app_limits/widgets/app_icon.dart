import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';

/// In-memory cache for decoded icon bytes.
final Map<String, Uint8List> _iconCache = {};

/// Displays an app icon from base64 or falls back to a first-letter avatar.
///
/// - [iconBase64] may be null, empty, or invalid; all are handled gracefully.
/// - [appName] is used for the first-letter fallback.
/// - [size] (default 40) controls both width and height.
class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    this.iconBase64,
    required this.appName,
    this.size = 40,
    this.borderRadius = 10,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String? iconBase64;
  final String appName;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.colors.surfaceVariant;
    final fg = foregroundColor ?? AppColors.primary;

    // Try base64 → image
    if (iconBase64 != null && iconBase64!.isNotEmpty) {
      final cached = _iconCache[iconBase64];
      if (cached != null) {
        return _buildImage(cached, bg);
      }
      try {
        final bytes = base64Decode(iconBase64!);
        _iconCache[iconBase64!] = bytes;
        return _buildImage(bytes, bg);
      } catch (_) {
        // Decode failed — fall through to avatar.
      }
    }

    // First-letter fallback
    return _buildAvatar(bg, fg);
  }

  Widget _buildImage(Uint8List bytes, Color bg) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAvatar(
          bg,
          foregroundColor ?? AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildAvatar(Color bg, Color fg) {
    final letter = appName.isNotEmpty ? appName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Text(
          letter,
          style: AppTypography.headlineSmall.copyWith(
            color: fg,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}
