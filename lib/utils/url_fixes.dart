import 'package:firebase_core/firebase_core.dart' as firebase_core;

/// Utilities to normalize and validate Firebase Storage download URLs.
///
/// Historically some URLs were saved with the wrong bucket (".firebasestorage.app")
/// inside the Google APIs path. These helpers validate and (for rendering only)
/// can soft-fix that case. For writes, we enforce exact bucket match.
const String kFirebaseDownloadUrlPattern =
    r'^https:\/\/firebasestorage\.googleapis\.com\/v0\/b\/.+\?alt=media&token=.+$';

bool isValidFirebaseDownloadUrl(String url) {
  try {
    return RegExp(kFirebaseDownloadUrlPattern).hasMatch(url);
  } catch (_) {
    return false;
  }
}

/// Validate the URL matches exactly the provided storage [bucket].
bool isValidFirebaseDownloadUrlForBucket(String url, String bucket) {
  if (bucket.trim().isEmpty) return false;
  final pattern =
      '^https\\:\\/\\/firebasestorage\\.googleapis\\.com\\/v0\\/b\\/${RegExp.escape(bucket)}\\/o\\/.+\\?alt=media&token=.+\$';
  try {
    return RegExp(pattern).hasMatch(url);
  } catch (_) {
    return false;
  }
}

/// Returns true if URL clearly contains a wrong bucket host inside /v0/b/...
bool isWrongFirebasestorageAppBucketUrl(String url) {
  try {
    return RegExp(r'\/v0\/b\/[^\/]*firebasestorage\.app\/o\/').hasMatch(url);
  } catch (_) {
    return false;
  }
}

/// Extract the object path (Storage name) from a valid download URL.
/// Returns null if not parseable. The returned path is decoded.
String? parseStorageObjectPathFromDownloadUrl(String url) {
  if (!url.contains('/v0/b/')) return null;
  try {
    final uri = Uri.parse(url);
    final p = uri.path; // e.g., /v0/b/<bucket>/o/<encodedPath>
    final idx = p.indexOf('/o/');
    if (idx == -1) return null;
    final encoded = p.substring(idx + 3); // after /o/
    if (encoded.isEmpty) return null;
    final decoded = Uri.decodeComponent(encoded);
    // decoded may still include extra path if any; but it's the object path
    return decoded;
  } catch (_) {
    return null;
  }
}

/// Best-effort soft normalization for rendering: if a URL was saved with the
/// ".firebasestorage.app" bucket embedded in the Google APIs path, rewrite just
/// the path segment to use ".appspot.com". Use only for display; do not save.
String fixFirebaseDownloadUrl(String url) {
  if (url.isEmpty) return url;
  // Fast path: only process if it clearly targets the Googleapis storage API
  if (!url.startsWith('http')) return url;
  if (!url.contains('firebasestorage.googleapis.com')) return url;

  try {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.toList();
    // Expect pattern: /v0/b/<bucket>/o/...
    final bIndex = segments.indexOf('b');
    if (bIndex != -1 && bIndex + 1 < segments.length) {
      final bucket = segments[bIndex + 1];
      if (bucket.contains('.firebasestorage.app')) {
        final fixedBucket = bucket.replaceAll('.firebasestorage.app', '.appspot.com');
        segments[bIndex + 1] = fixedBucket;
        final fixed = uri.replace(pathSegments: segments);
        return fixed.toString();
      }
    }
  } catch (_) {
    // ignore parse errors, return original
  }
  return url;
}

/// Fetch expected storage bucket from Firebase app options.
String expectedStorageBucket() {
  try {
    final app = firebase_core.Firebase.app();
    final bucket = app.options.storageBucket;
    if (bucket != null && bucket.trim().isNotEmpty) return bucket;
    final projectId = app.options.projectId;
    if (projectId.trim().isNotEmpty) return '${projectId}.appspot.com';
  } catch (_) {}
  return '';
}
