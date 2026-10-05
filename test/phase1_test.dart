// RideSync Phase 1 unit tests: validators, models, geo math.
// Pure-Dart (no Firebase/Supabase), run with `flutter test`.
import 'package:flutter_test/flutter_test.dart';

import 'package:ridesync/core/utils/validators.dart';
import 'package:ridesync/core/constants/app_constants.dart';
import 'package:ridesync/data/models/user_model.dart';
import 'package:ridesync/data/models/ride_models.dart';

void main() {
  group('validators (ID + password login path)', () {
    test('phone accepts 10 digits +91 variants', () {
      expect(validatePhone('9876543210'), isNull);
      expect(validatePhone('+91 9876543210'), isNull);
      expect(validatePhone('919876543210'), isNull);
    });
    test('phone rejects short/empty', () {
      expect(validatePhone(''), isNotNull);
      expect(validatePhone('12345'), isNotNull);
      expect(validatePhone(null), isNotNull);
    });
    test('otp must be 6 digits', () {
      expect(validateOtp('123456'), isNull);
      expect(validateOtp('123'), isNotNull);
      expect(validateOtp('abcdef'), isNotNull);
    });
    test('name required, email optional-but-valid', () {
      expect(validateName('Alok'), isNull);
      expect(validateName(''), isNotNull);
      expect(validateEmail(null), isNull);
      expect(validateEmail(''), isNull);
      expect(validateEmail('rider@test.com'), isNull);
      expect(validateEmail('not-an-email'), isNotNull);
    });
  });

  group('models round-trip (matches Supabase tables)', () {
    test('UserModel', () {
      const u = UserModel(
        id: 'uid-1',
        phone: '+919876543210',
        email: 'rider@test.com',
        fullName: 'Test Rider',
        defaultVehicleType: 'bike',
      );
      final back = UserModel.fromJson(u.toJson());
      expect(back.id, 'uid-1');
      expect(back.fullName, 'Test Rider');
      expect(back.defaultVehicleType, 'bike');
    });
    test('EmergencyContactModel priority 1-3', () {
      const c = EmergencyContactModel(
        userId: 'uid-1',
        name: 'Mom',
        phone: '9876543210',
        relationship: 'Parent',
        priority: 1,
      );
      expect(EmergencyContactModel.fromJson(c.toJson()).priority, 1);
    });
    test('VehicleModel slot states (spec)', () {
      const v = VehicleModel(
        id: 'v1',
        groupId: 'g1',
        vehicleType: 'bike',
        position: 1,
        role: 'leader',
      );
      expect(v.slotState(hasPendingInvite: false, ready: false), 'Empty');
      expect(v.slotState(hasPendingInvite: true, ready: false), 'Invited');
      const confirmed = VehicleModel(
        id: 'v1',
        groupId: 'g1',
        vehicleType: 'bike',
        driverId: 'uid-1',
      );
      expect(
          confirmed.slotState(hasPendingInvite: false, ready: false), 'Confirmed');
      expect(confirmed.slotState(hasPendingInvite: false, ready: true), 'Ready');
    });
    test('GroupModel defaults match migration', () {
      final g = GroupModel.fromJson({
        'id': 'g1',
        'name': 'Weekend Ride',
        'invite_code': '123456',
        'leader_id': 'uid-1',
      });
      expect(g.rideType, 'group');
      expect(g.vehicleType, 'bike');
      expect(g.distanceAlertThreshold, 1000);
      expect(g.status, 'planning');
    });
  });

  group('haversine (gap alerts)', () {
    test('same point is 0', () {
      expect(haversineMeters(28.6, 77.2, 28.6, 77.2), closeTo(0, 0.01));
    });
    test('~1km separation detected', () {
      // 0.009 deg latitude ≈ 1000m.
      final d = haversineMeters(28.6139, 77.2090, 28.6229, 77.2090);
      expect(d, greaterThan(900));
      expect(d, lessThan(1100));
    });
    test('500m threshold point is under 1km alert', () {
      final d = haversineMeters(28.6139, 77.2090, 28.6184, 77.2090);
      expect(d, lessThan(1000));
      expect(d, greaterThan(400));
    });
  });

  group('Phase 1 constants (spec)', () {
    test('tiers + limits', () {
      expect(AppConstants.activeIntervalSec, 10);
      expect(AppConstants.backgroundIntervalSec, 30);
      expect(AppConstants.stationaryIntervalSec, 60);
      expect(AppConstants.maxBikes, 20);
      expect(AppConstants.maxCars, 10);
      expect(AppConstants.maxEmergencyContacts, 3);
      expect(AppConstants.sosCancelWindowSec, 10);
      expect(AppConstants.inviteTtlHours, 24);
    });
  });
}
