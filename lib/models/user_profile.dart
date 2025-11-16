import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String fullName;
  final String username;
  final String email;
  final String phone;
  final String bio;
  final String gender; // 'Male', 'Female', 'Other', or ''
  final DateTime? dob;
  final String avatarUrl; // Network image URL; empty for placeholder
  final Uint8List? avatarBytes; // In-memory avatar when picked locally (camera/gallery/files)
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.fullName,
    required this.username,
    required this.email,
    required this.phone,
    required this.bio,
    required this.gender,
    required this.dob,
    required this.avatarUrl,
    this.avatarBytes,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? fullName,
    String? username,
    String? email,
    String? phone,
    String? bio,
    String? gender,
    DateTime? dob,
    String? avatarUrl,
    Uint8List? avatarBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarBytes: avatarBytes ?? this.avatarBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'username': username,
    'email': email,
    'phone': phone,
    'bio': bio,
    'gender': gender,
    'dob': dob != null ? Timestamp.fromDate(dob!) : null,
    'avatarUrl': avatarUrl,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  static UserProfile fromMap(Map<String, dynamic> map) {
    final dob = map['dob'] is Timestamp
        ? (map['dob'] as Timestamp).toDate()
        : (map['dob'] is String
            ? DateTime.tryParse(map['dob'] as String)
            : null);
    final createdAt = map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final updatedAt = map['updatedAt'] is Timestamp
        ? (map['updatedAt'] as Timestamp).toDate()
        : DateTime.now();
    return UserProfile(
      fullName: (map['fullName'] ?? '') as String,
      username: (map['username'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      bio: (map['bio'] ?? '') as String,
      gender: (map['gender'] ?? '') as String,
      dob: dob,
      avatarUrl: (map['avatarUrl'] ?? '') as String,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() =>
      'UserProfile(fullName: '+fullName+', username: '+username+', email: '+email+', phone: '+phone+', gender: '+gender+', dob: '+(dob?.toIso8601String() ?? '')+')';
}
