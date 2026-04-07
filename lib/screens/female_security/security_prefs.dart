import 'package:flutter/foundation.dart';

import '../../services/female_security/security_gate_scan_service.dart';

/// Shared preferences for female security module (e.g. selected gate).
final ValueNotifier<int> selectedGate = ValueNotifier<int>(3);
final ValueNotifier<String> selectedGateId = ValueNotifier<String>('gate_3');
final ValueNotifier<String> selectedCampusName = ValueNotifier<String>(
  'الزاهر',
);
final ValueNotifier<List<SecurityGateOption>> availableSecurityGates =
    ValueNotifier<List<SecurityGateOption>>(const []);

SecurityGateOption get currentSecurityGateOption {
  final gates = availableSecurityGates.value;
  for (final gate in gates) {
    if (gate.gateId == selectedGateId.value) {
      return gate;
    }
  }
  return SecurityGateOption.fallback(selectedGateId.value);
}

Future<void> loadSecurityGatePreferences() async {
  final service = FemaleSecurityGateScanService.instance;
  final gates = await service.loadAssignedGatesForCurrentUser();
  final defaultGateId = await service.loadDefaultGateIdForCurrentUser();
  final selected =
      gates.cast<SecurityGateOption?>().firstWhere(
        (gate) => gate?.gateId == defaultGateId,
        orElse: () => gates.isNotEmpty ? gates.first : null,
      ) ??
      SecurityGateOption.fallback(defaultGateId);

  availableSecurityGates.value = gates.isNotEmpty
      ? gates
      : <SecurityGateOption>[selected];
  selectedGateId.value = selected.gateId;
  selectedGate.value = selected.gateNumber;
  selectedCampusName.value = selected.campusName;
}

Future<void> updateSelectedGateOption(SecurityGateOption option) async {
  selectedGateId.value = option.gateId;
  selectedGate.value = option.gateNumber;
  selectedCampusName.value = option.campusName;
  await FemaleSecurityGateScanService.instance.updateDefaultGateForCurrentUser(
    option.gateId,
  );
}

/// Label for gate in header: "بوابة رقم 1", "بوابة رقم 2", etc.
String gateLabel([int? gate]) => 'بوابة رقم ${gate ?? selectedGate.value}';

/// Full gate label for card preview: "بوابة 1 - الزاهر", etc.
String gateLabelWithLocation([int? gate]) =>
    'بوابة ${gate ?? selectedGate.value} - ${selectedCampusName.value}';
