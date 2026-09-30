/// Message échangé entre citoyen et collecteur : `collections/{id}/messages`
/// (US-067). Aucun numéro de téléphone n'est jamais transmis.
class ChatMessage {
  const ChatMessage({required this.id, required this.fromUid, required this.text, this.at});
  final String id;
  final String fromUid;
  final String text;
  final DateTime? at;
}

const maxMessageLength = 500;

/// Numéros de téléphone (formats tunisiens et internationaux) masqués dans
/// les messages, pour préserver l'anonymat voulu par l'US-067.
final _phone = RegExp(r'(\+|00)?\d[\d\s.\-]{6,}\d');

String maskPhoneNumbers(String text) => text.replaceAllMapped(_phone, (m) {
  final digits = m[0]!.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 ? '•••• ••••' : m[0]!;
});

String? validateMessage(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'empty';
  if (t.length > maxMessageLength) return 'tooLong';
  return null;
}
