import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/call/zego_call_id.dart';

void main() {
  test('call ID is deterministic regardless of participant order', () {
    expect(buildOneToOneCallId('14', '3'), 'rehab_call_3_14');
    expect(buildOneToOneCallId('3', '14'), 'rehab_call_3_14');
    expect(
      buildOneToOneCallId('Patient 14', 'Therapist/3'),
      buildOneToOneCallId('Therapist/3', 'Patient 14'),
    );
  });

  test('ZEGO identifiers contain only supported characters', () {
    final userId = buildZegoUserId(' patient-14@example.com ');
    final callId = buildOneToOneCallId(' patient-14 ', 'therapist:3');
    final allowed = RegExp(r'^[A-Za-z0-9_]+$');

    expect(userId, 'patient_14_example_com');
    expect(allowed.hasMatch(userId), isTrue);
    expect(allowed.hasMatch(callId), isTrue);
    expect(userId.length, lessThanOrEqualTo(64));
    expect(callId.length, lessThanOrEqualTo(128));
  });

  test('very long call IDs stay deterministic and within ZEGO limit', () {
    final a = 'patient_${'a' * 100}';
    final b = 'therapist_${'b' * 100}';
    final first = buildOneToOneCallId(a, b);
    final reversed = buildOneToOneCallId(b, a);

    expect(first, reversed);
    expect(first.length, 128);
    expect(RegExp(r'^[A-Za-z0-9_]+$').hasMatch(first), isTrue);
  });

  test('blank or punctuation-only identity is rejected', () {
    expect(() => buildZegoUserId('  '), throwsFormatException);
    expect(() => buildOneToOneCallId('---', '3'), throwsFormatException);
  });
}
