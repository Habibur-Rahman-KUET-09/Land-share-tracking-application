import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// FR 7 "Payment Proof Upload (Mandatory)" — uploads a receipt image to
/// Firebase Storage and returns its download URL.
class StorageService {
  final FirebaseStorage _storage;
  StorageService({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadReceipt({
    required String groupId,
    required String uploaderUid,
    required File file,
  }) async {
    final ext = file.path.split('.').last;
    final ref = _storage
        .ref()
        .child('groups/$groupId/receipts/$uploaderUid-${DateTime.now().millisecondsSinceEpoch}.$ext');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }
}
