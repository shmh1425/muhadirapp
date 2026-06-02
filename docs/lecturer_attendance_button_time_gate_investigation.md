# Lecturer Attendance Button Time Gate Investigation

## 1. Problem Summary

Tomorrow lectures in the Lecturer home schedule can show the action label `حضر`, even though tomorrow lectures must not allow attendance-taking. The same Lecturer home UI also shows `حضر` for today's lecture cards whenever an attendance callback is passed, without checking whether the current local time is inside the lecture's actual start/end time range.

Required behavior is stricter than the current UI behavior: `حضر` should be visible only for a non-cancelled lecture scheduled for today, owned by the logged-in lecturer, when `now >= lectureStartDateTime` and `now <= lectureEndDateTime`.

## 2. Files Inspected

- `lib/screens/lecturer/lecturer_home_screen.dart` - renders the `محاضرات اليوم` and `محاضرات الغد` horizontal lecture sections and wires card actions.
- `lib/widgets/lecturer/lecture_card.dart` - reusable card that renders `حضر`, `تأخير المحاضرة`, and `إلغاء المحاضرة`.
- `lib/widgets/lecturer/lecture_timeline.dart` - passes lecture tap callbacks into `LectureCard`.
- `lib/widgets/lecturer/lecture_detail_card.dart` - bottom-sheet card for calendar day details.
- `lib/widgets/lecturer/day_details_bottom_sheet.dart` - navigates to editable or view-only attendance screens from calendar details.
- `lib/widgets/lecturer/day_tap_handler.dart` - decides whether calendar dates open editable/view-only details.
- `lib/screens/lecturer/lecturer_navigation.dart` - central navigation into `LecturerAttendanceScreen`.
- `lib/screens/lecturer/lecturer_attendance_screen.dart` - target attendance screen; resolves sessions and activates manual/QR/NFC/Bluetooth flows.
- `lib/screens/lecturer/lecturer_nfc_session_management_screen.dart` - standalone NFC session controls and current time-window UI checks.
- `lib/screens/lecturer/lecturer_qr_screen.dart` - searched for QR session activation entry points.
- `lib/services/lecturer/filter_service.dart` - filters lectures into today/tomorrow by weekday.
- `lib/services/lecturer/lecture_repository.dart` - resolves current date from `academic_calendar/current` or local fallback and active-term metadata.
- `lib/services/lecturer/calendar_service.dart` - builds calendar day status from normalized dates.
- `lib/repositories/lecturer_catalog_repository.dart` - reads Firestore `sections` and `sections.schedule` data.
- `lib/models/lecturer/unified_lecturer_catalog.dart` - converts catalog rows into `LectureItem`.
- `lib/models/lecturer/lecture_item.dart` - contains lecture start/end time behavior.
- `lib/utils/shared/time_utils.dart` - sorts and formats lecture times.
- `lib/utils/shared/date_utils.dart` - date display helper; no attendance gating logic.
- `lib/utils/lecture_action_eligibility.dart` - existing delay/cancel end-time eligibility helper.
- `lib/services/notifications/lecture_action_notification_service.dart` - stores and reads delay/cancel status in `lecture_actions`.
- `lib/services/attendance/attendance_status_policy.dart` - existing QR/NFC/Bluetooth attendance-window policy.
- `lib/services/attendance/manual_attendance_service.dart` - creates manual attendance sessions and records.
- `lib/services/attendance/qr_attendance_service.dart` - creates/opens QR sessions and validates student QR submission windows.
- `lib/services/attendance/nfc_attendance_service.dart` - opens NFC sessions and validates active sessions for student attendance.
- `lib/services/attendance/bluetooth_attendance_service.dart` - opens Bluetooth sessions and validates student signal submission windows.

## 3. Current UI Behavior Found

The `حضر` label is rendered in `LectureCard`. The only condition is `if (onTap != null)`, so any non-null card tap callback becomes a visible attendance chip. The card does not know the lecture date, current time, cancellation status, or ownership.

In `LecturerHomeScreen`, both today and tomorrow sections use `_buildDayLecturesMainCard`, which renders each item through `_buildHorizontalLectureTile`, which then creates `LectureCard`. Today's section passes `onAttendTap: _openAttendanceForToday`. Tomorrow's section passes `onAttendTap: _openAttendanceForTomorrowViewOnly`. Because both are non-null, both sections show `حضر`.

Tomorrow navigation is view-only (`LecturerNavigation.goToAttendanceViewOnly`) and uses `_normalizedTomorrow()`, but the button text still says `حضر`. This means the current card condition checks neither date nor time. It only checks whether a tap callback exists.

Delay/cancel actions are always passed from `_buildHorizontalLectureTile` through `onDelayTap` and `onCancelTap`. The actual duplicate/cancel/expired checks happen later in `LectureActionNotificationService`, not before rendering the chips.

## 4. Current Time Validation Logic

Lecture schedule data is loaded from Firestore `sections` where `lecturerId == current lecturer id`. Each active section's `schedule` array provides `dayOfWeek`, `startTime`, `endTime`, `hall`, `activity`, and optional `location`. `LecturerCatalogRepository` normalizes `startTime` and `endTime` to `HH:mm`; invalid/missing values fall back to defaults such as `08:00` and `10:00`.

`LectureItem.startTime` stores the normalized schedule start. `LectureItem.endTime` is derived from `scheduleEndTime` minus `systemEndOffsetMinutes` of 10 minutes. If no schedule end exists, it derives 50 minutes for a single lecture or 110 minutes for a double lecture.

Today/tomorrow grouping in `FilterService` uses `DateTime.weekday` from `baseDate` or `baseDate + 1 day`, then filters lectures by `lecture.dayOfWeek`. The home screen passes `baseDate: _repository.currentDateTime`; that value is loaded from Firestore `academic_calendar/current.currentDateTime` or `currentDate`, with `DateTime.now()` as fallback.

Existing attendance service time validation uses `AttendanceStatusPolicy.isSessionWithinAttendanceWindow`. That helper combines lecture date plus `HH:mm` strings into `DateTime`, supports an overnight end by adding one day when end is before start, and allows an early window of 20 minutes before start plus a late window of 30 minutes after end. This is not the same as the requested strict button rule.

Timezone risk: the code relies on local `DateTime.now()` plus Firestore `Timestamp.toDate()` / stored calendar timestamps. There is no explicit app-wide timezone conversion in the inspected gating paths. If Firestore test dates and device local time differ, today/tomorrow grouping and active-window checks can drift.

Parsing risk: `LectureItem` and `TimeUtils` use direct `int.parse` for `HH:mm` values. `LecturerCatalogRepository` normalizes schedule times defensively before constructing `LectureItem`, but any manually constructed or stale cached `LectureItem` with malformed time can throw during UI rendering or time calculation.

## 5. Root Cause

Confirmed root cause: attendance button visibility is tied to callback presence instead of attendance eligibility. `LectureCard` displays `حضر` whenever `onTap` is non-null. `LecturerHomeScreen` passes a non-null `onAttendTap` to both today's and tomorrow's lecture sections. No date, current time, active range, cancellation status, or service-level eligibility is checked before rendering the chip.

Confirmed secondary cause: tomorrow is wired as view-only navigation but still uses the same `حضر` label path. The tomorrow section passes `_openAttendanceForTomorrowViewOnly`, so the button is not actually an attendance-taking button in navigation mode, but it is rendered and labelled exactly like one.

Confirmed service mismatch: QR, NFC, and Bluetooth student submissions use the broader `AttendanceStatusPolicy` window. QR and Bluetooth session creation can call `ManualAttendanceService.prepareSessionForLecture` before rejecting outside-window usage. Manual save also prepares a session without a strict active-time gate. Therefore hiding the UI button alone would not fully prevent direct navigation or session creation outside the requested strict window.

## 6. Affected Screens / Features

- Lecturer home `محاضرات اليوم`: shows `حضر` for all today lectures in the list, regardless of whether the lecture is currently active.
- Lecturer home `محاضرات الغد`: shows `حضر` because a view-only callback is passed, even though tomorrow lectures should never show attendance-taking action.
- Reusable `LectureCard`: any caller that passes `onTap` receives a `حضر` chip.
- Calendar day details: today/past editable dates can navigate into attendance from `LectureDetailCard`; this path is not labelled `حضر` but can still reach the attendance screen.
- Lecturer attendance screen: direct navigation can resolve a session id; manual save, QR activation, NFC activation, and Bluetooth activation are the important creation paths to guard.
- QR attendance: student QR submission checks today/window, but QR session creation is not strictly gated before session creation/opening.
- NFC attendance: standalone NFC management has UI disabling for today/window, but uses the broader early/late window. Service open still prepares the manual session before any inspected service-level active-window rejection.
- Bluetooth attendance: student signal submission checks today/window, but session opening prepares/opens sessions before the later student submission window.
- Delay/cancel lecture actions: separate logic exists and may remain, but cancellation status is stored in `lecture_actions` and is not available on `LectureItem` during home card rendering.

## 7. Recommended Fix Plan

Create one shared strict helper for lecturer attendance start eligibility. Keep it separate from `AttendanceStatusPolicy.isSessionWithinAttendanceWindow`, because the existing policy intentionally allows early/late windows for QR/NFC/Bluetooth student check-in behavior.

Suggested shape:

```dart
bool canTakeAttendanceForLecture({
  required DateTime lectureDate,
  required DateTime startDateTime,
  required DateTime endDateTime,
  required DateTime now,
  required String? lectureStatus,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final lectureDay = DateTime(lectureDate.year, lectureDate.month, lectureDate.day);
  if (lectureDay != today) return false;
  if ((lectureStatus ?? '').trim().toLowerCase() == 'cancelled' ||
      (lectureStatus ?? '').trim().toLowerCase() == 'canceled') {
    return false;
  }
  if (now.isBefore(startDateTime)) return false;
  if (now.isAfter(endDateTime)) return false;
  return true;
}
```

Recommended use:

- In `lib/screens/lecturer/lecturer_home_screen.dart`, calculate attendance eligibility per lecture/date before passing `onAttendTap` into `LectureCard`.
- For tomorrow lectures, pass `onAttendTap: null` or a differently labelled view-only action; do not show `حضر`.
- Before `LecturerNavigation.goToAttendance` for editable attendance, block if the helper returns false.
- In `lib/screens/lecturer/lecturer_attendance_screen.dart`, block manual save, QR activation, NFC activation, and Bluetooth activation when the strict helper fails.
- In `ManualAttendanceService.prepareSessionForLecture` or a narrow wrapper around it, add service-level validation before creating session docs. This is needed because QR/NFC/Bluetooth services call it.
- Load cancellation status from `LectureActionNotificationService.loadLectureActionStatuses` for today/tomorrow cards, or pass a `LectureActionStatus` map into the card builder so cancelled lectures cannot show `حضر`.

## 8. Suggested User Messages

- Future lecture: `لا يمكن بدء التحضير قبل وقت المحاضرة.`
- Tomorrow lecture: `لا يمكن بدء التحضير لمحاضرة غير مجدولة اليوم.`
- Ended lecture: `انتهى وقت المحاضرة ولا يمكن بدء التحضير.`
- Cancelled lecture: `لا يمكن بدء التحضير لمحاضرة ملغاة.`

## 9. Test Cases Needed

| Test ID | Scenario | Expected Result |
| --- | --- | --- |
| LTG-01 | Tomorrow lecture | `حضر` is hidden |
| LTG-02 | Today lecture before start time | `حضر` is hidden |
| LTG-03 | Today lecture during active time | `حضر` is visible |
| LTG-04 | Today lecture after end time | `حضر` is hidden |
| LTG-05 | Cancelled lecture during active time | `حضر` is hidden |
| LTG-06 | Time range crosses parsing edge case | Correct `DateTime` comparison |
| LTG-07 | Direct navigation attempt outside time | Blocked with Arabic message |
| LTG-08 | Attendance session creation outside time | Blocked or safely rejected |

## 10. Final Recommendation

Change these exact areas first:

- `lib/widgets/lecturer/lecture_card.dart`: do not let `onTap` alone imply the label `حضر`; either receive an explicit attendance action or render a generic/view-only action separately.
- `lib/screens/lecturer/lecturer_home_screen.dart`: replace the unconditional `onAttendTap` passed to today/tomorrow cards with strict eligibility. Tomorrow should not pass an attendance callback.
- `lib/screens/lecturer/lecturer_attendance_screen.dart`: guard manual save and QR/NFC/Bluetooth activation with the same strict helper.
- `lib/services/attendance/manual_attendance_service.dart`: add or call service-level validation before session creation, because multiple attendance methods rely on this service.
- `lib/services/attendance/qr_attendance_service.dart`, `lib/services/attendance/nfc_attendance_service.dart`, and `lib/services/attendance/bluetooth_attendance_service.dart`: ensure session open/create paths reject outside strict lecturer-start eligibility before writing session docs.

Service-level validation is recommended in addition to UI validation. UI hiding fixes the visible bug, but direct navigation or method activation can still create/open sessions unless the service path also rejects invalid date/time/cancelled states.

Risks before implementation:

- Cancellation state is not part of `LectureItem`; it must be fetched from `lecture_actions`.
- Existing `AttendanceStatusPolicy` has a 20-minute early and 30-minute late window, so reusing it would not satisfy the requested strict `start <= now <= end` rule.
- `LectureItem.endTime` subtracts 10 minutes from `sections.schedule[].endTime`; confirm this is still the intended system end for attendance gating.
- The app uses local device time and Firestore calendar time without an explicit timezone abstraction.
- Some direct service calls currently create manual session records before student-side window checks.

## Analyzer / Verification

Command run:

```sh
flutter analyze
```

Result: failed with 32 existing analyzer issues. No implementation code was changed for this investigation, so these were not introduced by this report.

Existing issues reported:

- 13 warnings, mostly unnecessary casts and unused elements/locals in chatbot/offline files.
- 19 infos, including deprecated `value` usage, `BuildContext` across async gaps, unnecessary imports, style lints, and one dangling library doc comment.

No new app code errors were introduced because this task only added the Markdown investigation report.

## 11. Implementation Summary

Files changed:

- `lib/utils/lecturer_attendance_eligibility.dart`
- `lib/widgets/lecturer/lecture_card.dart`
- `lib/screens/lecturer/lecturer_home_screen.dart`
- `lib/screens/lecturer/lecturer_attendance_screen.dart`
- `lib/screens/lecturer/lecturer_qr_screen.dart`
- `lib/screens/lecturer/lecturer_nfc_session_management_screen.dart`
- `lib/services/attendance/manual_attendance_service.dart`
- `docs/lecturer_attendance_button_time_gate_investigation.md`

Helper added:

- Added `LecturerAttendanceEligibility` with strict `lectureDate == today`, `now >= start`, `now <= end`, and cancelled-status checks.
- Added `LecturerAttendanceBlockedException` so service-level guards can surface the same neutral Arabic block messages.

Exact UI behavior fixed:

- `LectureCard` no longer treats any generic `onTap` as an attendance action unless `showAttendanceAction` is true.
- `LecturerHomeScreen` now passes an attendance callback to today's lecture card only when the lecture is currently eligible.
- `LecturerHomeScreen` no longer passes an attendance callback to tomorrow lecture cards, so tomorrow lectures do not show `حضر`.
- Cancelled lecture status is loaded narrowly from `lecture_actions` for today/tomorrow home cards before showing `حضر`.

Service-level validation:

- Added strict validation in `ManualAttendanceService.prepareSessionForLecture` before explicit manual session creation.
- Because QR, NFC, and Bluetooth session creation/opening call `prepareSessionForLecture`, those paths are also rejected before session docs are written for non-today, before-start, after-end, or cancelled lectures.
- Added direct navigation protection in `LecturerAttendanceScreen` before loading editable attendance.
- Added blocked-exception handling in Lecturer attendance, QR/Bluetooth, and NFC-management screens to show localized user-facing messages instead of raw exceptions.

Remaining risks:

- The home screen hides `حضر` until cancellation status is successfully loaded. If `lecture_actions` cannot be read, the safer result is no attendance button.
- The date source for grouping still uses `LectureRepository.currentDateTime`, while the strict active-time helper uses local `DateTime.now()`.
- `LectureItem.endTime` still applies the existing system rule of `sections.schedule[].endTime - 10 minutes`.
- Existing pre-task edits were present in several touched files; they were left in place and not reverted.

Analyzer result:

- Ran `flutter analyze`.
- Result remained 32 existing warnings/infos from unrelated files.
- No new analyzer issue was reported from the files changed for this implementation.

## 12. Final Manual Verification

Verification type: code-path review only. These scenarios were not manually verified from an emulator/device in this environment, and no runtime screenshots or live Firestore write/no-write evidence were available. Therefore these items remain pending final manual verification.

| Scenario | Expected Result | Verification Type | Actual Result | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| Tomorrow lecture | `حضر` hidden | Code-path reviewed only | Not manually verified from emulator/device | Pending manual verification | No screenshot available |
| Today lecture before start time | `حضر` hidden | Code-path reviewed only | Not manually verified from emulator/device | Pending manual verification | No screenshot available |
| Today lecture during active time | `حضر` visible | Code-path reviewed only | Not manually verified from emulator/device | Pending manual verification | No screenshot available |
| Today lecture after end time | `حضر` hidden | Code-path reviewed only | Not manually verified from emulator/device | Pending manual verification | No screenshot available |
| Direct navigation/session creation outside active time | Blocked with the correct Arabic message and no session document created | Code-path reviewed only | Not manually verified from emulator/device or live Firestore | Pending manual verification | No screenshot or Firestore document evidence available |

Final note about the 10-minute end-time offset:

- The strict eligibility helper receives `LectureItem.endTime`.
- Current `LectureItem.endTime` behavior applies the existing offset rule: when `sections.schedule[].endTime` exists, the effective end is `sections.schedule[].endTime - 10 minutes`.
- Therefore, with the current code, a raw scheduled lecture from `07:00` to `07:50` is treated as attendance-active until `07:40`, not `07:50`.
- This confirms current code behavior only. It does not confirm product/business intent.
- No code change was made for this cutoff. A product decision is still needed: attendance cutoff should be either the effective system end (`07:40`) or the raw schedule end (`07:50`).
