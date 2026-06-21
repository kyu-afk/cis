import 'dart:convert';

String encryptString(String text) {
  String encrypted = '';
  List<int> bytes;
  try {
    bytes = utf8.encode(text);
    encrypted = base64.encode(bytes);
  } catch (e) {
    encrypted = '';
  }
  return encrypted;
}

String decryptString(String encrString) {
  List<int> bytes;
  String decrypted = '';
  try {
    bytes = base64.decode(encrString);
    decrypted = utf8.decode(bytes);
  } on FormatException {
    decrypted = '';
  }
  return decrypted;
}
