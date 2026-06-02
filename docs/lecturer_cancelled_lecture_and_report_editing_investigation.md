# Lecturer Cancelled Lecture and Report Editing Investigation

## 1. Problem Summary

The final product decision for cancelled lectures is:

- A cancelled lecture should still materialize in attendance reports as default-present when the lecturer never opened attendance.
- Students should be counted present by default for that cancelled lecture.
- The report should appear and behave like a normal default-present report.
- Starting/creating live attendance for a cancelled lecture should remain blocked.

The second issue remains separate: lecturers should be able to edit existing attendance reports after the lecture time has ended.

## 2. Observed Behavior

The report sync policy already creates default-present sessions for ended scheduled lectures that were never opened by the lecturer. This behavior is now intentional for cancelled lectures too.

The editing restriction came from `LecturerAttendanceScreen`, where saving an existing report still depended on active lecture eligibility and called the guarded creation method `prepareSessionForLecture`.

## 3. Files Inspected

- `lib/services/attendance/attendance_report_term_service.dart` - term report sync and default-present report creation trigger.
- `lib/services/attendance/manual_attendance_service.dart` - start eligibility, cancellation lookup, session creation, default-present materialization, record loading, and status updates.
- `lib/screens/lecturer/lecturer_attendance_report_screen.dart` - report loading, report grouping, inline editing, and export controls.
- `lib/screens/lecturer/lecturer_attendance_screen.dart` - attendance screen loading, save path, edit enablement, and QR/NFC/Bluetooth start controls.
- `lib/features/attendance/attendance_entry_point.dart` - UI-facing manual batch submission API.
- `lib/features/attendance/attendance_unified_service.dart` - manual batch delegation to offline/online save path.
- `lib/models/attendance/manual_attendance_record.dart` - supported statuses: pending, present, absent, excused, late.
- `lib/models/attendance/manual_attendance_session.dart` - session metadata flags for opened/default-present sessions.
- `lib/services/notifications/lecture_action_notification_service.dart` - `lecture_actions` cancellation status used by strict start eligibility.
- `lib/utils/lecturer_attendance_eligibility.dart` - strict start/create eligibility and cancelled/after-end block messages.

## 4. Current Cancelled Lecture Flow

Cancellation status is stored in `lecture_actions` and loaded through `LectureActionNotificationService.loadLectureActionStatuses`.

`ManualAttendanceService.checkAttendanceStartEligibility` still uses this lookup and passes `lectureStatus: 'canceled'` into `LecturerAttendanceEligibility`, so starting live attendance for a cancelled lecture remains blocked.

Report materialization is separate. `AttendanceReportTermService.syncAndLoadSectionSessions` calls `ManualAttendanceService.ensureDefaultPresentSessionForEndedLecture` for ended scheduled lectures with no known session. That method now intentionally does not block default-present materialization for cancelled lectures.

The default-present write path creates:

- A `manual_attendance_sessions` document with `attendanceMethod: default_present`, `sessionWasOpened: false`, `explicitSessionOpened: false`, and `defaultPresentPolicyApplied: true`.
- One `manual_attendance_records` document per active enrolled student with `status: present`.

## 5. Current Report Editing Flow

`LecturerAttendanceReportScreen` loads report groups from persisted sessions and lets inline report editing save directly to the existing `group.sessionId` through `AttendanceEntryPoint.submitManualBatch`.

`LecturerAttendanceScreen` now detects whether a session document already exists. Existing sessions can be edited with the existing session id. New manual attendance creation still goes through `prepareSessionForLecture`.

## 6. Root Cause

Cancelled lecture behavior is no longer considered a bug after the product decision changed. The desired behavior is to keep the existing default-present report policy for cancelled lectures.

Editing root cause: `LecturerAttendanceScreen` previously used one strict active-window flag for both starting new attendance and editing existing records. `_saveChanges` also called `prepareSessionForLecture` before every save, even when the report/session already existed.

## 7. Required Behavior

Cancelled lectures:

- Should create default-present records after the reporting window when the lecturer never opened attendance.
- Should count students as present by default.
- Should appear as a normal default-present attendance report.

Existing reports:

- Should be viewable.
- Should be editable by the authorized lecturer.
- Should be savable after lecture end.

New attendance creation:

- Should remain blocked outside active lecture time.
- Should remain blocked for cancelled lectures.
- Should remain blocked for tomorrow/future lectures.

## 8. Implemented Fix

Cancelled lecture report behavior:

- No cancellation block is applied inside `ManualAttendanceService.ensureDefaultPresentSessionForEndedLecture`.
- No cancelled/no-attendance virtual group is built in `LecturerAttendanceReportScreen`.
- Cancelled lectures follow the existing default-present policy and appear as normal reports.

Existing report editing behavior:

- `LecturerAttendanceScreen` separates `_canStartAttendanceNow` from `_canEditAttendanceNow`.
- Existing session detection uses `ManualAttendanceService.getSessionById`.
- `_saveChanges` updates an existing session id directly through `AttendanceEntryPoint.submitManualBatch`.
- `prepareSessionForLecture` is still used only when a new manual session must be created.
- QR, NFC, and Bluetooth action buttons use `_canStartAttendanceNow`, so start actions remain strictly gated.

## 9. Test Cases Needed

| Test ID | Scenario | Expected Result |
|---|---|---|
| CLR-01 | Cancelled lecture with no opened attendance session | Default-present session/records are created after the lecture reporting window |
| CLR-02 | Cancelled lecture appears in report | Shows as a normal default-present report |
| CLR-03 | Cancelled lecture with existing real records before cancellation | Existing records are preserved |
| CLR-04 | Existing report after lecture end | Lecturer can edit and save records |
| CLR-05 | Existing report before lecture start | Lecturer can edit if report already exists |
| CLR-06 | Non-existing session after lecture end | New live attendance creation is blocked |
| CLR-07 | Starting manual attendance for cancelled lecture | Blocked |
| CLR-08 | QR/NFC/Bluetooth start for cancelled lecture | Blocked |
| CLR-09 | Export cancelled lecture default-present report | Export works like a normal report |
| CLR-10 | Normal active lecture | Attendance start and editing still work normally |

## 10. Final Recommendation

No Firestore schema, indexes, rules, QR payload, session id format, Student module, Female Security module, or Admin module changes are needed.

The important separation is:

- Cancelled lecture report accounting: default-present is allowed and intentional.
- Cancelled lecture live attendance start: still blocked.
- Existing report correction: allowed after lecture end.

## 11. Implementation Summary

Files changed:

- `lib/services/attendance/manual_attendance_service.dart`
- `lib/screens/lecturer/lecturer_attendance_report_screen.dart`
- `lib/screens/lecturer/lecturer_attendance_screen.dart`
- `docs/lecturer_cancelled_lecture_and_report_editing_investigation.md`

What changed for cancelled lectures:

- Removed the cancellation suppression from default-present report materialization.
- Removed cancelled/no-attendance UI handling from the report screen.
- Cancelled lectures now create/report default-present attendance like normal ended lectures with no opened session.

What changed for editing existing reports:

- Existing sessions can be edited without calling strict start/create eligibility.
- Saving an existing report uses its existing session id.
- Creating a new manual session still uses strict eligibility.

Analyzer:

- `flutter analyze` result is recorded in the final response for this task.
