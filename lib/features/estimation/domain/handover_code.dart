import 'dart:math';

/// Alphabet sans caractères ambigus (0/O, 1/I/L).
const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const handoverCodeLength = 8;

/// Code de pesée à donner au collecteur (US-028). Aléatoire cryptographique :
/// 31^8 ≈ 8,5·10^11 combinaisons, impossible à deviner.
String generateHandoverCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(handoverCodeLength, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
}

/// Normalise une saisie (« 7kx2-9qpa » → « 7KX29QPA »), `null` si invalide.
String? normalizeHandoverCode(String input) {
  final t = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  if (t.length != handoverCodeLength) return null;
  return t.split('').every(_alphabet.contains) ? t : null;
}

/// Affichage lisible : « 7KX2-9QPA ».
String formatHandoverCode(String code) =>
    code.length == handoverCodeLength ? '${code.substring(0, 4)}-${code.substring(4)}' : code;
