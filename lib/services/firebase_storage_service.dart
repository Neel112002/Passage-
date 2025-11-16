import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:passage/firebase_options.dart';
import 'package:passage/utils/url_fixes.dart';
// Image compression for faster, more reliable uploads on slow networks
import 'package:image/image.dart' as img;

// Uploaded image result and FirebaseStorageService live below.

class UploadedImage {
  final String path; // e.g., products/{uid}/{listingId}/{ts}_{i}.jpg
  final String downloadUrl; // exact string returned by getDownloadURL()
  UploadedImage({required this.path, required this.downloadUrl});
}

/// Firebase Storage helper for uploading product media.
class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a single product image and return its Storage [path] and the exact
  /// download URL from getDownloadURL().
  ///
  /// Default path: products/<sellerId>/<timestamp>_<rand>.<ext>
  /// If [listingId] is provided, path becomes: products/<sellerId>/<listingId>/<timestamp>_<index>.<ext>
  static Future<UploadedImage> uploadProductImage(
    Uint8List bytes, {
    required String sellerId,
    String? listingId,
    int? index,
    String extension = 'jpg',
    bool allowDataUrlFallback = true,
  }) async {
    // Try to compress large images for faster upload and fewer timeouts
    final comp = await _maybeCompress(bytes, extension);
    bytes = comp.bytes;
    extension = comp.extension; // ensure path + contentType match new encoding
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeExt = _normalizeExt(extension);
    final contentType = _guessImageMime(safeExt);
    String path;
    if (listingId != null && listingId.isNotEmpty) {
      final idx = (index ?? 0).clamp(0, 999999);
      path = 'products/$sellerId/$listingId/${ts}_$idx.$safeExt';
    } else {
      final rand = Random().nextInt(0xFFFFFF).toRadixString(16);
      path = 'products/$sellerId/${ts}_$rand.$safeExt';
    }
    // Strategy:
    // - Always use the official Firebase Storage SDK on web to avoid CORS.
    // - Do NOT use REST on web (browsers will block cross-origin without bucket CORS).
    // - Retry SDK uploads with exponential backoff.
    // - Use generous timeouts on web, but avoid actively cancelling the task to
    //   prevent false timeouts when browsers throttle background tabs.
    final uploadTimeout = kIsWeb
        ? const Duration(minutes: 5)
        : const Duration(seconds: 60);
    final urlTimeout = kIsWeb
        ? const Duration(minutes: 2)
        : const Duration(seconds: 30);
    try {
      return await _uploadWithRetry(
        bytes,
        path: path,
        contentType: contentType,
        uploadTimeout: uploadTimeout,
        urlTimeout: urlTimeout,
        maxAttempts: 3,
      );
    } on TimeoutException catch (_) {
      // On web, we never fall back to REST to avoid CORS; propagate so caller
      // can surface an actionable error. On non-web, same behavior.
      rethrow;
    } catch (e) {
      // Do not use REST on web. If caller allows data URL fallback (used only in
      // non-critical flows), return that; otherwise rethrow so the publish flow
      // stays strictly Storage-first.
      if (allowDataUrlFallback) {
        final b64 = base64Encode(bytes);
        final dataUrl = 'data:$contentType;base64,$b64';
        // ignore: avoid_print
        print('StorageUpload: failure after retries; returning data URL for path='+path+' err='+e.toString());
        return UploadedImage(path: '', downloadUrl: dataUrl);
      }
      rethrow;
    }
  }

  /// Upload a user's avatar image to Storage and return its path and canonical
  /// download URL from getDownloadURL().
  static Future<UploadedImage> uploadUserAvatar(
    Uint8List bytes, {
    required String userId,
    String extension = 'jpg',
  }) async {
    // Compress avatars lightly
    final comp = await _maybeCompress(bytes, extension);
    bytes = comp.bytes;
    extension = comp.extension;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeExt = _normalizeExt(extension);
    final contentType = _guessImageMime(safeExt);
    final path = 'avatars/$userId/avatar_$ts.$safeExt';
    return _uploadWithRetry(
      bytes,
      path: path,
      contentType: contentType,
      uploadTimeout: kIsWeb ? const Duration(minutes: 5) : const Duration(seconds: 60),
      urlTimeout: kIsWeb ? const Duration(seconds: 90) : const Duration(seconds: 30),
      maxAttempts: 3,
    );
  }

  /// Build a getDownloadURL for an existing storage [path] under default bucket.
  /// Validates and canonicalizes the URL before returning.
  static Future<String> getDownloadUrlForPath(String path) async {
    final ref = _storage.ref().child(path);
    String url = await ref.getDownloadURL();
    if (isWrongFirebasestorageAppBucketUrl(url)) {
      url = fixFirebaseDownloadUrl(url);
    }
    final expectedBucket = expectedStorageBucket();
    if (!isValidFirebaseDownloadUrlForBucket(url, expectedBucket)) {
      // Retry once from SDK
      url = await ref.getDownloadURL();
      if (isWrongFirebasestorageAppBucketUrl(url)) {
        url = fixFirebaseDownloadUrl(url);
      }
    }
    if (!isValidFirebaseDownloadUrlForBucket(url, expectedBucket)) {
      throw Exception('Invalid download URL for path: $path');
    }
    return url;
  }

  static String _normalizeExt(String ext) {
    var e = ext.toLowerCase().replaceAll('.', '').trim();
    if (e.isEmpty) e = 'jpg';
    if (e == 'jpeg') e = 'jpg';
    return e;
  }

  static String _guessImageMime(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'image/jpeg';
    }
  }
}

class _CompressedResult {
  final Uint8List bytes;
  final String extension; // 'jpg' when re-encoded
  _CompressedResult(this.bytes, this.extension);
}

/// Best-effort compression to reduce upload size and avoid timeouts.
/// - If the image is larger than ~1.2MB or wider than 1600px, it will be
///   resized to max 1600px on the longer side and encoded as JPEG(85).
/// - If decoding fails, returns original bytes and extension.
Future<_CompressedResult> _maybeCompress(Uint8List bytes, String ext) async {
  try {
    // Skip tiny images
    if (bytes.lengthInBytes < (1.2 * 1024 * 1024)) return _CompressedResult(bytes, ext);
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return _CompressedResult(bytes, ext);
    final int maxSide = 1600;
    img.Image processed = decoded;
    final longer = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longer > maxSide) {
      processed = img.copyResize(decoded, width: decoded.width >= decoded.height ? maxSide : null, height: decoded.height > decoded.width ? maxSide : null);
    }
    final jpg = img.encodeJpg(processed, quality: 85);
    // Only use compressed if it's actually smaller
    if (jpg.length < bytes.lengthInBytes) {
      // ignore: avoid_print
      print('StorageUpload: compressed image from ${bytes.lengthInBytes} to ${jpg.length} bytes');
      return _CompressedResult(Uint8List.fromList(jpg), 'jpg');
    }
    return _CompressedResult(bytes, ext);
  } catch (_) {
    return _CompressedResult(bytes, ext);
  }
}

// SDK upload helper
Future<UploadedImage> _uploadViaSdk(
  Uint8List bytes, {
  required String path,
  required String contentType,
  required Duration uploadTimeout,
  required Duration urlTimeout,
}) async {
  final ref = FirebaseStorage.instance.ref().child(path);
  final metadata = SettableMetadata(contentType: contentType);
  // ignore: avoid_print
  print('StorageUpload: SDK putData start path='+path+' ct='+contentType+' bytes='+bytes.lengthInBytes.toString());
  final UploadTask uploadTask = ref.putData(bytes, metadata);
  // On web, avoid actively cancelling the task with a timeout to prevent
  // false timeouts when the browser throttles network in background tabs.
  // On other platforms, keep a reasonable timeout.
  TaskSnapshot snapshot;
  if (kIsWeb) {
    snapshot = await uploadTask;
  } else {
    snapshot = await uploadTask.timeout(uploadTimeout, onTimeout: () {
      // ignore: avoid_print
      print('StorageUpload: SDK upload timed out path='+path);
      try { uploadTask.cancel(); } catch (_) {}
      throw TimeoutException('SDK upload timed out');
    });
  }
  // ignore: avoid_print
  print('StorageUpload: SDK completed state='+snapshot.state.name+' path='+path);
  String url = await ref.getDownloadURL().timeout(urlTimeout, onTimeout: () {
    throw TimeoutException('getDownloadURL timed out');
  });
  if (isWrongFirebasestorageAppBucketUrl(url)) {
    url = fixFirebaseDownloadUrl(url);
  }
  final expectedBucket = expectedStorageBucket();
  if (!isValidFirebaseDownloadUrlForBucket(url, expectedBucket)) {
    url = await ref.getDownloadURL();
    if (isWrongFirebasestorageAppBucketUrl(url)) {
      url = fixFirebaseDownloadUrl(url);
    }
  }
  if (!isValidFirebaseDownloadUrlForBucket(url, expectedBucket)) {
    throw Exception('Invalid download URL for bucket: '+expectedBucket);
  }
  return UploadedImage(path: path, downloadUrl: url);
}

Future<UploadedImage> _uploadWithRetry(
  Uint8List bytes, {
  required String path,
  required String contentType,
  required Duration uploadTimeout,
  required Duration urlTimeout,
  int maxAttempts = 3,
}) async {
  int attempt = 0;
  Object? lastError;
  while (attempt < maxAttempts) {
    attempt++;
    final backoffMs = attempt == 1 ? 0 : (pow(2, attempt - 2) * 800).toInt();
    if (backoffMs > 0) {
      // ignore: avoid_print
      print('StorageUpload: retrying attempt=$attempt path='+path+' backoffMs='+backoffMs.toString());
      await Future.delayed(Duration(milliseconds: backoffMs));
    }
    try {
      return await _uploadViaSdk(
        bytes,
        path: path,
        contentType: contentType,
        uploadTimeout: uploadTimeout,
        urlTimeout: urlTimeout,
      );
    } catch (e) {
      lastError = e;
      // ignore: avoid_print
      print('StorageUpload: attempt $attempt failed for path='+path+' err='+e.toString());
      // If canceled explicitly, do not retry further.
      if (e is FirebaseException && e.code == 'canceled') break;
      if (attempt >= maxAttempts) break;
    }
  }
  // Propagate the last error after exhausting attempts
  if (lastError is TimeoutException) throw lastError;
  if (lastError is FirebaseException) throw lastError;
  throw Exception('Upload failed after $maxAttempts attempts: $lastError');
}

// REST upload helper (not used on web by default). Kept for reference and
// potential server-side tooling. Do not call from web flows to avoid CORS.
// ignore: unused_element
Future<UploadedImage> _uploadViaRest(Uint8List bytes, {required String path, required String contentType}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('Not signed in');
  }
  final idToken = await user.getIdToken();
  final options = DefaultFirebaseOptions.web;
  final bucket = _resolveBucketForRest(options);
  final uri = Uri.parse(
    'https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=${Uri.encodeComponent(path)}&uploadType=media',
  );
  // ignore: avoid_print
  print('StorageUpload: REST start path='+path+' bucket='+bucket);
  final resp = await http
      .post(
    uri,
    headers: {
      'Content-Type': contentType,
      // For Firebase Storage v0 REST API, use Firebase ID token auth scheme.
      // Using Bearer here triggers auth failures/CORS in some browsers.
      'Authorization': 'Firebase $idToken',
      // Hint CORS preflight that this is a simple raw upload.
      // Not strictly required for v0, but safe and helps some environments.
      'X-Goog-Upload-Protocol': 'raw',
    },
    body: bytes,
  )
      .timeout(const Duration(seconds: 35), onTimeout: () {
    // ignore: avoid_print
    print('StorageUpload: REST upload timed out for path='+path);
    throw TimeoutException('REST upload timed out');
  });
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    throw Exception('Storage upload failed (${resp.statusCode}): ${resp.body}');
  }

  final ref = FirebaseStorage.instance.ref().child(path);
  String url = await ref.getDownloadURL().timeout(const Duration(seconds: 15), onTimeout: () {
    throw TimeoutException('getDownloadURL timed out');
  });
  if (isWrongFirebasestorageAppBucketUrl(url)) {
    url = fixFirebaseDownloadUrl(url);
  }
  final expectedBucket = expectedStorageBucket();
  if (!isValidFirebaseDownloadUrlForBucket(url, expectedBucket)) {
    url = await ref.getDownloadURL();
    if (isWrongFirebasestorageAppBucketUrl(url)) {
      url = fixFirebaseDownloadUrl(url);
    }
  }
  if (!isValidFirebaseDownloadUrlForBucket(url, expectedBucket)) {
    throw Exception('Invalid download URL after REST upload for bucket: '+expectedBucket);
  }
  // ignore: avoid_print
  print('StorageUpload: REST success path='+path+' url='+url);
  return UploadedImage(path: path, downloadUrl: url);
}

/// Normalize the Firebase Storage bucket host for REST uploads.
/// Converts web host forms like "<project>.firebasestorage.app" into
/// "<project>.appspot.com", strips schemes/paths, and falls back to
/// "<projectId>.appspot.com" when needed.
String _resolveBucketForRest(FirebaseOptions options) {
  // Default to <projectId>.appspot.com
  String bucket = '${options.projectId}.appspot.com';
  try {
    // Prefer storageBucket if provided
    String raw = options.storageBucket ?? '';
    raw = raw.trim();
    if (raw.isNotEmpty) {
      // Remove scheme and any path piece
      raw = raw.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');
      if (raw.contains('/')) raw = raw.split('/').first;
      // Convert to canonical host
      raw = raw.replaceAll('.firebasestorage.app', '.appspot.com');
      if (raw.endsWith('.appspot.com')) {
        bucket = raw;
      }
    }
  } catch (_) {
    // ignore and use default
  }
  return bucket;
}
