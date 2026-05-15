import 'package:flutter/foundation.dart';

import '../../features/translation/translation_controller.dart';
import 'geo_fence_outcome.dart';
import 'geo_fence_service.dart';

/// Campus geo-fence for **students** (attendance + gate card). Security staff skip this.
class StudentCampusGeoGuard {
  StudentCampusGeoGuard._();

  /// `null` = allowed; otherwise the student must not proceed.
  static Future<GeoFenceOutcome?> blockingOutcome() async {
    if (kIsWeb) return null;
    final outcome = await GeoFenceService.instance.evaluateCampusBoundary();
    return outcome == GeoFenceOutcome.inside ? null : outcome;
  }

  static String localizedMessage(GeoFenceOutcome outcome) {
    final en = TranslationController.instance.translateToEnglish;
    switch (outcome) {
      case GeoFenceOutcome.inside:
        return en ? 'Inside campus.' : 'داخل نطاق الحرم.';
      case GeoFenceOutcome.outsideCampus:
        return en
            ? 'You must be on campus to use this feature.'
            : 'يجب أن تكون داخل الحرم الجامعي لاستخدام هذه الميزة.';
      case GeoFenceOutcome.permissionDenied:
        return en
            ? 'Location permission is required. Enable it in device settings.'
            : 'يلزم إذن الموقع. فعّله من إعدادات الجهاز.';
      case GeoFenceOutcome.locationServiceDisabled:
        return en
            ? 'Turn on location services in device settings.'
            : 'فعّل خدمة الموقع من إعدادات الجهاز.';
      case GeoFenceOutcome.locationUnavailable:
        return en
            ? 'Unable to verify your location. Try again.'
            : 'تعذر التحقق من موقعك. حاول مرة أخرى.';
    }
  }
}
