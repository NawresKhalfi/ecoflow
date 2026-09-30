/// Service Bluetooth standard « Weight Scale » (0x181D) et sa
/// caractéristique « Weight Measurement » (0x2A9D) (US-049).
const weightScaleService = '181d';
const weightMeasurementCharacteristic = '2a9d';

/// Décode une mesure « Weight Measurement » (spécification Bluetooth SIG) :
/// octet 0 = drapeaux (bit 0 : 1 = impérial), octets 1–2 = poids uint16
/// little-endian, résolution 0,005 kg (SI) ou 0,01 lb (impérial).
/// Renvoie des kilogrammes, ou `null` si la trame est invalide ou la mesure
/// indisponible (0xFFFF).
double? parseWeightMeasurement(List<int> bytes) {
  if (bytes.length < 3) return null;
  final flags = bytes[0];
  final raw = bytes[1] | (bytes[2] << 8);
  if (raw == 0xFFFF) return null;
  final imperial = flags & 0x01 == 1;
  return imperial ? raw * 0.01 * 0.45359237 : raw * 0.005;
}
