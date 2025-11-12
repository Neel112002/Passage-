import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions, Firebase;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:passage/firebase_options.dart';
import 'package:passage/utils/url_fixes.dart';

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
  }) async {
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
    // - On web: use REST-first to avoid rare SDK stalls in sandboxed web envs.
    // - On mobile/desktop: use SDK; keep strict timeouts.
    if (kIsWeb) {
      // ignore: avoid_print
      print('StorageUpload: using REST-first (web) path='+path);
      try {
        return await _uploadViaRest(bytes, path: path, contentType: contentType);
      } catch (e) {
        // ignore: avoid_print
        print('StorageUpload: REST failed on web, falling back to SDK. error='+e.toString());
        return _uploadViaSdk(bytes, path: path, contentType: contentType);
      }
    }

    return _uploadViaSdk(bytes, path: path, contentType: contentType);
  }

  /// Upload a user's avatar image to Storage and return its path and canonical
  /// download URL from getDownloadURL().
  static Future<UploadedImage> uploadUserAvatar(
    Uint8List bytes, {
    required String userId,
    String extension = 'jpg',
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeExt = _normalizeExt(extension);
    final contentType = _guessImageMime(safeExt);
    final path = 'avatars/$userId/avatar_$ts.$safeExt';
    if (kIsWeb) {
      // ignore: avoid_print
      print('AvatarUpload: using REST-first (web) path='+path);
      try {
        return await _uploadViaRest(bytes, path: path, contentType: contentType);
      } catch (e) {
        // ignore: avoid_print
        print('AvatarUpload: REST failed on web, falling back to SDK. error='+e.toString());
        return _uploadViaSdk(bytes, path: path, contentType: contentType);
      }
    }
    return _uploadViaSdk(bytes, path: path, contentType: contentType);
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

// SDK upload helper (non-web preferred)
Future<UploadedImage> _uploadViaSdk(Uint8List bytes, {required String path, required String contentType}) async {
  final ref = FirebaseStorage.instance.ref().child(path);
  final metadata = SettableMetadata(contentType: contentType);
  // ignore: avoid_print
  print('StorageUpload: SDK putData start path='+path+' ct='+contentType+' bytes='+bytes.lengthInBytes.toString());
  final UploadTask uploadTask = ref.putData(bytes, metadata);
  final snapshot = await uploadTask.timeout(const Duration(seconds: 35), onTimeout: () {
    // ignore: avoid_print
    print('StorageUpload: SDK upload timed out path='+path);
    try { uploadTask.cancel(); } catch (_) {}
    throw TimeoutException('SDK upload timed out');
  });
  // ignore: avoid_print
  print('StorageUpload: SDK completed state='+snapshot.state.name+' path='+path);
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
    throw Exception('Invalid download URL for bucket: '+expectedBucket);
  }
  return UploadedImage(path: path, downloadUrl: url);
}

// REST upload helper (web preferred)
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
