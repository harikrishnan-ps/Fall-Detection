import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../Encryption/ascon.dart';
import '../../utils/hex_utils.dart';

class EncryptionTestScreen extends StatefulWidget {
  const EncryptionTestScreen({Key? key}) : super(key: key);

  @override
  State<EncryptionTestScreen> createState() => _EncryptionTestScreenState();
}

class _EncryptionTestScreenState extends State<EncryptionTestScreen> {
  final _keyController = TextEditingController();
  final _nonceController = TextEditingController();
  final _adController = TextEditingController();
  final _ciphertextController = TextEditingController();

  String _result = "";
  bool _isSuccess = false;

  void _decrypt() {
    final keyBytes = HexUtils.fromHex(_keyController.text);
    final nonceBytes = HexUtils.fromHex(_nonceController.text);
    final adBytes = HexUtils.fromHex(_adController.text) ?? Uint8List(0);
    final ciphertextBytes = HexUtils.fromHex(_ciphertextController.text);

    if (keyBytes == null || nonceBytes == null || ciphertextBytes == null) {
      setState(() {
        _result = "Invalid Hex Input";
        _isSuccess = false;
      });
      return;
    }

    try {
      final ascon = Ascon();
      final plaintext = ascon.decrypt(
        ciphertext: ciphertextBytes,
        key: keyBytes,
        nonce: nonceBytes,
        associatedData: adBytes,
      );

      setState(() {
        if (plaintext != null) {
          _isSuccess = true;
          // Try to decode as UTF-8 string, or just show hex
          try {
            final text = String.fromCharCodes(plaintext);
            _result = "Success!\nHex: ${HexUtils.toHex(plaintext)}\nText: $text";
          } catch (_) {
            _result = "Success!\nHex: ${HexUtils.toHex(plaintext)}";
          }
        } else {
          _isSuccess = false;
          _result = "Decryption Failed (Tag Mismatch)";
        }
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _result = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ascon Decryption Test")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(labelText: "Key (Hex)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nonceController,
              decoration: const InputDecoration(labelText: "Nonce (Hex)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _adController,
              decoration: const InputDecoration(labelText: "Associated Data (Hex - Optional)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ciphertextController,
              decoration: const InputDecoration(labelText: "Ciphertext (Hex)"),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _decrypt,
              child: const Text("Decrypt"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _keyController.text = "000102030405060708090a0b0c0d0e0f";
                  _nonceController.text = "a0a1a2a3a4a5a6a7a8a9aaabacadaeaf";
                  _adController.text = "";
                  _ciphertextController.text =
                      "a83367c0328d297d3b32841fb359d992a9ac15491de3f075a18617c650";
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
              ),
              child: const Text("Load Test Case (Golduck Glove)"),
            ),
            const SizedBox(height: 20),
            Text(
              "Result:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              color: _isSuccess ? Colors.green[50] : Colors.red[50],
              child: Text(
                _result,
                style: TextStyle(
                  color: _isSuccess ? Colors.green[900] : Colors.red[900],
                  fontFamily: 'Courier',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
