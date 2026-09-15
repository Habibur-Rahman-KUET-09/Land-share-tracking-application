import 'package:cloud_firestore/cloud_firestore.dart';

/// A registered user (users/{uid}) — profile info shared across every group
/// they belong to. Auth identity (phone/email) lives in FirebaseAuth itself;
/// this document is the app-facing profile (display name, contact info).
class AppUser {
  final String uid;
  final String name;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    this.phone,
    this.email,
    this.photoUrl,
    required this.createdAt,
  });

  AppUser copyWith({String? name, String? phone, String? email, String? photoUrl}) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: (map['name'] as String?) ?? '',
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
