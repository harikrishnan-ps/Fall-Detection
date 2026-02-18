import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart'; // For calloc and malloc

// --- C Function Signature ---
// int crypto_aead_decrypt(
//    unsigned char* m, unsigned long long* mlen,
//    unsigned char* nsec, const unsigned char* c,
//    unsigned long long clen, const unsigned char* ad,
//    unsigned long long adlen, const unsigned char* npub,
//    const unsigned char* k
// )
typedef CryptoDecryptC = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8> m,       // Output: Plaintext
  ffi.Pointer<ffi.Uint64> mlen,   // Output: Plaintext Length
  ffi.Pointer<ffi.Uint8> nsec,    // Unused
  ffi.Pointer<ffi.Uint8> c,       // Input: Ciphertext
  ffi.Uint64 clen,                // Input: Ciphertext Length
  ffi.Pointer<ffi.Uint8> ad,      // Input: Associated Data
  ffi.Uint64 adlen,               // Input: AD Length
  ffi.Pointer<ffi.Uint8> npub,    // Input: Nonce
  ffi.Pointer<ffi.Uint8> k,       // Input: Key
);

// --- Dart Function Signature ---
typedef CryptoDecryptDart = int Function(
  ffi.Pointer<ffi.Uint8> m,
  ffi.Pointer<ffi.Uint64> mlen,
  ffi.Pointer<ffi.Uint8> nsec,
  ffi.Pointer<ffi.Uint8> c,
  int clen,
  ffi.Pointer<ffi.Uint8> ad,
  int adlen,
  ffi.Pointer<ffi.Uint8> npub,
  ffi.Pointer<ffi.Uint8> k,
);

class Ascon {
  late ffi.DynamicLibrary _lib;
  late CryptoDecryptDart _decryptFunc;

  Ascon() {
    // 1. Open the library
    if (Platform.isAndroid) {
      // Assuming libascon.so is in the JNI libs path
      _lib = ffi.DynamicLibrary.open('libascon.so');
    } else if (Platform.isLinux) {
       _lib = ffi.DynamicLibrary.open('./libascon.so');
    } else {
      // Fallback for testing or other platforms
      // For iOS it might be 'ascon.framework/ascon' or similar checking Process
      if (Platform.isIOS) {
          _lib = ffi.DynamicLibrary.process();
      } else {
          throw UnsupportedError('Platform not supported for Ascon FFI');
      }
    }

    try {
        // 2. Lookup the function
        _decryptFunc = _lib.lookupFunction<CryptoDecryptC, CryptoDecryptDart>(
          'crypto_aead_decrypt',
        );
    } catch (e) {
        // Handle lookup failure gracefully or rethrow
        print('Error looking up crypto_aead_decrypt: $e');
        rethrow;
    }
  }

  /// Decrypts [ciphertext] using ASCON.
  /// Returns [Uint8List] of plaintext if successful, or null if verification fails.
  Uint8List? decrypt({
    required Uint8List ciphertext,
    required Uint8List key,
    required Uint8List nonce,
    Uint8List? associatedData,
  }) {
    associatedData ??= Uint8List(0);

    // --- Memory Allocation ---
    // We must manually allocate C memory on the heap.
    // 'm' (plaintext) can be at most 'clen' bytes long.
    final mPtr = calloc<ffi.Uint8>(ciphertext.length);
    final mlenPtr = calloc<ffi.Uint64>(1);
    final cPtr = calloc<ffi.Uint8>(ciphertext.length);
    final adPtr = calloc<ffi.Uint8>(associatedData.length);
    final npubPtr = calloc<ffi.Uint8>(nonce.length);
    final kPtr = calloc<ffi.Uint8>(key.length);

    try {
      // --- Copy Data to C Pointers ---
      // We copy byte-by-byte to ensure safe transfer to the C heap
      for (var i = 0; i < ciphertext.length; i++) {
        cPtr[i] = ciphertext[i];
      }
      for (var i = 0; i < associatedData.length; i++) {
        adPtr[i] = associatedData[i];
      }
      for (var i = 0; i < nonce.length; i++) {
        npubPtr[i] = nonce[i];
      }
      for (var i = 0; i < key.length; i++) {
        kPtr[i] = key[i];
      }

      // --- Call C Function ---
      final result = _decryptFunc(
        mPtr,
        mlenPtr,
        ffi.nullptr, // nsec is unused in your C code
        cPtr,
        ciphertext.length,
        adPtr,
        associatedData.length,
        npubPtr,
        kPtr,
      );

      // --- Handle Result ---
      if (result != 0) {
        // Ascon returns -1 if authentication fails (tag mismatch)
        return null;
      }

      // Extract the actual plaintext length and data
      final actualLen = mlenPtr.value;
      final plaintext = Uint8List(actualLen);
      for (var i = 0; i < actualLen; i++) {
        plaintext[i] = mPtr[i];
      }

      return plaintext;

    } finally {
      // --- Cleanup ---
      // Crucial: Free the manual memory to avoid leaks
      calloc.free(mPtr);
      calloc.free(mlenPtr);
      calloc.free(cPtr);
      calloc.free(adPtr);
      calloc.free(npubPtr);
      calloc.free(kPtr);
    }
  }
}
