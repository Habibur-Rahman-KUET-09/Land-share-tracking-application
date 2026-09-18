import 'package:flutter/material.dart';

import '../services/user_directory.dart';

/// Resolves a uid to its display name — shared by every screen that lists
/// members/contributions by id (dashboard, transparency, reports, lottery,
/// audit log).
///
/// The lookup goes through [UserDirectory], which caches it; this widget is
/// rebuilt constantly by the streams behind those screens, and a fresh
/// Firestore read per rebuild was costing real money for a name that almost
/// never changes.
class MemberName extends StatelessWidget {
  final String uid;
  final TextStyle? style;
  const MemberName({super.key, required this.uid, this.style});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: UserDirectory.instance.name(uid),
      builder: (context, snap) => Text(snap.data ?? '…', style: style),
    );
  }
}
