import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/app_role.dart';
import 'package:mobile_core/core/config/bd_phone.dart';
import 'package:mobile_core/core/config/static_test_user.dart';
import 'package:mobile_core/core/models/models.dart';
import 'package:mobile_core/core/network/error_codes.dart';
import 'package:mobile_core/core/network/mock_backend.dart';

void main() {
  test('phone validator matches BD mobiles', () {
    final b = MockBackend();
    expect(b.validPhone('1712345678'), isTrue);
    expect(b.validPhone('01712345678'), isTrue);
    expect(b.validPhone('1111111111'), isFalse);
  });

  test('taka format uses latin digits', () {
    expect(formatTaka(1250), '৳1,250');
  });

  test('static QA phone 0152170004 is accepted', () {
    expect(BdPhone.isValid('0152170004'), isTrue);
    expect(BdPhone.normalize('0152170004'), '0152170004');
    expect(BdPhone.isQa('+880152170004'), isTrue);
  });

  test('QA user logs in with OTP 123456 and skips onboarding', () async {
    final b = MockBackend();
    await b.requestOtp('0152170004', online: true);
    final passenger = await b.verifyOtp(
      national10: '0152170004',
      otp: '123456',
      role: AppRole.passenger,
    );
    expect(passenger.phone, '0152170004');
    expect(passenger.name, StaticTestUser.name);
    expect(passenger.needsName, isFalse);
    expect(passenger.locationPrimed, isTrue);
    expect(passenger.isVerified, isTrue);
    expect(b.history, isNotEmpty);
    expect(b.guardians.length, 2);

    final driver = await b.verifyOtp(
      national10: '0152170004',
      otp: StaticTestUser.otp,
      role: AppRole.driver,
    );
    expect(driver.onboarding, DriverOnboardingStatus.approved);
    expect(driver.debtBlocked, isFalse);
    expect(b.earnings().debt, 0);
  });

  test('QA user can book, match, cash, SOS', () async {
    final b = MockBackend();
    await b.requestOtp('0152170004', online: true);
    await b.verifyOtp(
      national10: '0152170004',
      otp: '123456',
      role: AppRole.passenger,
    );
    final ride = await b.createRide(
      pickup: const LatLng(23.7925, 90.4078),
      drop: const LatLng(23.7937, 90.4066),
      pickupLabel: 'Gulshan 2',
      dropLabel: 'Banani',
      type: MockBackend.car,
    );
    expect(ride.status, RideStatus.requested);
    final matched = await b.matchDemo();
    expect(matched.driver, isNotNull);
    await b.advance(RideStatus.inProgress);
    final sos = await b.triggerSos(allowed: true);
    expect(sos.status, 'active');
    await b.advance(RideStatus.completed);
    await b.confirmCash(matched.fare.total);
    expect(b.cashConfirmed, isTrue);
  });
}
