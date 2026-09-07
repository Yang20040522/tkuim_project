const int _zegoUserIdMaxLength = 64;
const int _zegoCallIdMaxLength = 128;

final RegExp _invalidZegoCharacter = RegExp(r'[^A-Za-z0-9_]');
final RegExp _hasLetterOrNumber = RegExp(r'[A-Za-z0-9]');

String buildZegoUserId(String value) {
  final sanitized = _sanitize(value);
  if (!_hasLetterOrNumber.hasMatch(sanitized)) {
    throw const FormatException('ZEGO user ID is invalid.');
  }
  return sanitized.length <= _zegoUserIdMaxLength
      ? sanitized
      : sanitized.substring(0, _zegoUserIdMaxLength);
}

String buildOneToOneCallId(String userA, String userB) {
  final participants = [
    _sanitizeParticipant(userA),
    _sanitizeParticipant(userB)
  ]..sort(_compareParticipantIds);
  final callId = 'rehab_call_${participants[0]}_${participants[1]}';
  if (callId.length <= _zegoCallIdMaxLength) return callId;

  final suffix = _stableHashHex(callId);
  final prefixLength = _zegoCallIdMaxLength - suffix.length - 1;
  return '${callId.substring(0, prefixLength)}_$suffix';
}

int _compareParticipantIds(String left, String right) {
  final leftNumber = int.tryParse(left);
  final rightNumber = int.tryParse(right);
  if (leftNumber != null && rightNumber != null) {
    final numericOrder = leftNumber.compareTo(rightNumber);
    if (numericOrder != 0) return numericOrder;
  }
  return left.compareTo(right);
}

String _sanitizeParticipant(String value) {
  final sanitized = _sanitize(value);
  if (!_hasLetterOrNumber.hasMatch(sanitized)) {
    throw const FormatException('ZEGO participant ID is invalid.');
  }
  return sanitized;
}

String _sanitize(String value) =>
    value.trim().replaceAll(_invalidZegoCharacter, '_');

String _stableHashHex(String value) {
  final forward = _fnv32(value.codeUnits);
  final reverse = _fnv32(value.codeUnits.reversed);
  return '${forward.toRadixString(16).padLeft(8, '0')}'
      '${reverse.toRadixString(16).padLeft(8, '0')}';
}

int _fnv32(Iterable<int> units) {
  const mask = 0xFFFFFFFF;
  var hash = 0x811c9dc5;
  for (final unit in units) {
    hash ^= unit;
    hash = (hash * 0x01000193) & mask;
  }
  return hash;
}
