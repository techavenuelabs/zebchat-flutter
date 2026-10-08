import 'package:flutter/foundation.dart';
import 'package:zebchat_flutter/src/zebchat.dart' show ZebChat;

/// The signed-in user of your app, passed to [ZebChat.setUser].
///
/// Agents see these details next to the conversation, and the conversation
/// history follows the user across devices. With identity verification on, send
/// [id] together with [hash] = `hex(HMAC-SHA256(identitySecret, id))`, computed
/// **on your server**; never ship the identity secret in the app.
@immutable
class ZebChatUser {
  /// Creates a user. Every field is optional; [id] and [hash] go together.
  const ZebChatUser({this.id, this.email, this.name, this.phone, this.hash});

  /// Your stable user id.
  final String? id;

  /// The user's email address.
  final String? email;

  /// The user's display name.
  final String? name;

  /// The user's phone number.
  final String? phone;

  /// Server-computed identity verification HMAC.
  final String? hash;

  /// The method-channel payload (unset fields are left out).
  Map<String, String> toMap() => <String, String>{
        if (id != null) 'id': id!,
        if (email != null) 'email': email!,
        if (name != null) 'name': name!,
        if (phone != null) 'phone': phone!,
        if (hash != null) 'hash': hash!,
      };

  @override
  bool operator ==(Object other) =>
      other is ZebChatUser &&
      other.id == id &&
      other.email == email &&
      other.name == name &&
      other.phone == phone &&
      other.hash == hash;

  @override
  int get hashCode => Object.hash(id, email, name, phone, hash);

  /// Keeps personal data and the hash out of logs (like the native SDKs).
  @override
  String toString() => 'ZebChatUser(id: ${_mask(id)}, email: ${_mask(email)}, '
      'name: ${_mask(name)}, phone: ${_mask(phone)}, hash: ${_mask(hash)})';

  static String _mask(String? value) => value == null ? 'null' : '…';
}
