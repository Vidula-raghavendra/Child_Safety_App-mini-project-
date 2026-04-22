import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_profile.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Stream<UserProfile?> streamProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromMap(snap.data()!, snap.id);
    });
  }

  Future<void> updateLocation(String uid, Position pos) async {
    await _db.collection('users').doc(uid).update({
      'lastKnownLocation': GeoPoint(pos.latitude, pos.longitude),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> generateLinkingCode(String uid) async {
    final code = (100000 + (FieldValue.serverTimestamp().hashCode % 900000)).toString().substring(0, 6);
    await _db.collection('users').doc(uid).update({
      'linkingCode': code,
    });
  }

  Future<bool> linkAccounts(String childUid, String code) async {
    final query = await _db.collection('users')
      .where('role', isEqualTo: 'parent')
      .where('linkingCode', isEqualTo: code)
      .limit(1)
      .get();

    if (query.docs.isEmpty) return false;

    final parentId = query.docs.first.id;

    final batch = _db.batch();
    batch.update(_db.collection('users').doc(parentId), {
      'linkedUid': childUid,
      'linkingCode': "",
    });
    batch.update(_db.collection('users').doc(childUid), {
      'linkedUid': parentId,
    });

    await batch.commit();
    return true;
  }
}
