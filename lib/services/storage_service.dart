import 'package:cross_file/cross_file.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// FR 7 "Payment Proof Upload" — uploads a receipt image to Firebase
/// Storage and returns its download URL.
///
/// Takes an [XFile] (what image_picker hands back) and uploads its bytes
/// rather than a `dart:io` File: on the web a picked image has no real
/// path — only a blob URL — so `putFile` can't work there at all, while
/// `putData` is the same one call on every platform.
class StorageService {
  final FirebaseStorage _storage;
  StorageService({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadReceipt({
    required String groupId,
    required String uploaderUid,
    required XFile file,
  }) async {
    // A blob URL has no extension, so fall back to jpg rather than saving
    // the file under a garbage one.
    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    final bytes = await file.readAsBytes();
    final ref = _storage
        .ref()
        .child('groups/$groupId/receipts/$uploaderUid-${DateTime.now().millisecondsSinceEpoch}.$ext');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: file.mimeType ?? 'image/$ext'),
    );
    return task.ref.getDownloadURL();
  }
}
