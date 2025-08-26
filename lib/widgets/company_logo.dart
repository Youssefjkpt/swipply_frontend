import 'package:flutter/material.dart';

/// Returns true if [s] looks like an absolute http/https URL.
bool _looksLikeUrl(String s) {
  if (s.trim().isEmpty) return false;
  final uri = Uri.tryParse(s);
  return uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}

String _initials(String raw) {
  final trimmed = raw.trim();

  // Nothing to work with → single “?” (or return '' if you prefer blank)
  if (trimmed.isEmpty) return 'FT';

  // Throw away the empty chunks that split() may create
  final parts =
      trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  if (parts.isEmpty) return 'FT';

  // Helper: first glyph of a word, works for composed characters
  String firstChar(String word) => word.characters.first;

  if (parts.length == 1) {
    final word = parts.first;
    // Pick the first *two* glyphs if the word is long enough, otherwise one.
    final take = word.characters.take(2).toList().join();
    return take.toUpperCase();
  }

  // Two or more words → first of first + first of last
  return (firstChar(parts.first) + firstChar(parts.last)).toUpperCase();
}

/* ───────────────────────── reusable info dialog ────────────────────────── */
class CompanyLogo extends StatelessWidget {
  const CompanyLogo(this.rawValue, {super.key});

  final String rawValue;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    final size = const Size.square(75);

    // Case 1: the string is (or at least looks like) a URL
    if (_looksLikeUrl(rawValue)) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          rawValue,
          height: size.height,
          width: size.width,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image_not_supported, size: 30),
        ),
      );
    }

    // Case 2: fallback “text logo”
    return Container(
      height: size.height,
      width: size.width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black, // <- background
        borderRadius: borderRadius,
      ),
      child: Text(
        _initials(rawValue),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Colors.white, // <- text colour
        ),
      ),
    );
  }
}
