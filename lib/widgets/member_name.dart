import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';

/// Resolves a uid to its users/{uid} display name — shared by every screen
/// that lists members/contributions by id (dashboard, transparency, reports).
class MemberName extends StatelessWidget {
  final String uid;
  final TextStyle? style;
  const MemberName({super.key, required this.uid, this.style});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        final name = snap.data?.exists == true ? AppUser.fromMap(uid, snap.data!.data()!).name : uid;
        return Text(name, style: style);
      },
    );
  }
}
