import 'dart:typed_data';

class HexUtils {
  static Uint8List? fromHex(String hex) {
    try {
      hex = hex.replaceAll(' ', '').toUpperCase();
      if (hex.length % 2 != 0) {
        return null; // Invalid length
      }
      final result = Uint8List(hex.length ~/ 2);
      for (var i = 0; i < hex.length; i += 2) {
        final byte = int.parse(hex.substring(i, i + 2), radix: 16);
        result[i ~/ 2] = byte;
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  static String toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }
}
