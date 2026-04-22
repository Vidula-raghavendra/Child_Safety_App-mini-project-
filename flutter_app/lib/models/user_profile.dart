import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String role;
  final String? linkedUid;
  final String? linkingCode;
  final String displayName;
  final DateTime createdAt;
  final GeoPoint? lastKnownLocation;
  final DateTime? locationUpdatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    this.linkedUid,
    this.linkingCode,
    required this.displayName,
    required this.createdAt,
    this.lastKnownLocation,
    this.locationUpdatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      email: data['email'] ?? '',
      role: data['role'] ?? 'child',
      linkedUid: data['linkedUid'],
      linkingCode: data['linkingCode'],
      displayName: data['displayName'] ?? 'User',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastKnownLocation: data['lastKnownLocation'] as GeoPoint?,
      locationUpdatedAt: (data['locationUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'linkedUid': linkedUid,
      'linkingCode': linkingCode,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastKnownLocation': lastKnownLocation,
      'locationUpdatedAt': locationUpdatedAt != null ? Timestamp.fromDate(locationUpdatedAt!) : null,
    };
  }
}
