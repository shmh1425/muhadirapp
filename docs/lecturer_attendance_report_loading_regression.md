# Lecturer Attendance Report Loading Regression Investigation

## 1. Problem Summary

After commit `2bf25b633004d77d6668d9a3cf0d91b22efb8917` (`fix(lecturer): gate attendance action by lecture time`), opening an existing lecturer attendance/report view after the lecture has ended can show:

- `تعذر تحميل بيانات التحضير`
- `انتهى وقت المحاضرة ولا يمكن بدء التحضير`

The strict time gate should block starting, creating, or writing attendance after the active lecture window. It should not block reading an existing attendance session, viewing the report/list, exporting a report, or opening a view-only attendance screen.

## 2. Observed Behavior

Reported behavior:

- The lecturer opens the attendance/report screen after the lecture end time.
- The screen fails during attendance data loading.
- The UI displays the load-failure title `تعذر تحميل بيانات التحضير` and the strict-start blocked message `انتهى وقت المحاضرة ولا يمكن بدء التحضير`.

This message is valid for starting attendance after the lecture end. It is not valid for loading an existing report or existing attendance records.

## 3. Files Inspected

- `lib/utils/lecturer_attendance_eligibility.dart` - strict helper and Arabic blocked messages.
- `lib/screens/lecturer/lecturer_attendance_screen.dart` - screen initialization, session id resolution, record stream attachment, save, QR/NFC/Bluetooth actions, and load-error UI.
- `lib/screens/lecturer/lecturer_qr_screen.dart` - QR/Bluetooth session activation catches strict blocked exceptions.
- `lib/screens/lecturer/lecturer_nfc_session_management_screen.dart` - standalone NFC opening catches strict blocked exceptions.
- `lib/services/attendance/manual_attendance_service.dart` - strict guard before session creation, read methods, report methods, record loading, and session updates.
- `lib/services/attendance/qr_attendance_service.dart` - QR creation calls `ManualAttendanceService.prepareSessionForLecture`.
- `lib/services/attendance/nfc_attendance_service.dart` - NFC opening calls `ManualAttendanceService.prepareSessionForLecture`.
- `lib/services/attendance/bluetooth_attendance_service.dart` - Bluetooth opening calls `ManualAttendanceService.prepareSessionForLecture`.
- `lib/screens/lecturer/lecturer_attendance_report_screen.dart` - report loading, opening attendance from report groups, and export actions.
- `lib/services/attendance/attendance_report_term_service.dart` - report-wide session sync and default-present materialization for ended lectures.
- `lib/services/attendance/attendance_session_export_service.dart` - single-session export entry point.
- `lib/services/attendance/export/attendance_session_export_model.dart` - export model read path for session and records.
- Commit inspected: `2bf25b633004d77d6668d9a3cf0d91b22efb8917`.

## 4. Current Flow When Opening Attendance/Report Screen

`LecturerAttendanceReportScreen` loads report groups through `AttendanceReportTermService.syncAndLoadSectionSessions`, then `ManualAttendanceService.getSessionsForSectionIds`. Record details load through `ManualAttendanceService.getRecordsForSessionIds`. These report read paths do not call `checkAttendanceStartEligibility` or `prepareSessionForLecture`.

When the report screen opens a specific attendance group for editing, it calls `LecturerNavigation.goToAttendance`. That lands in `LecturerAttendanceScreen`.

In `LecturerAttendanceScreen._loadManualAttendance`:

1. The screen resolves the session id with `ManualAttendanceService.buildSessionId`.
2. If `_effectiveViewOnly` is false, it calls `_attendanceStartEligibility`.
3. `_attendanceStartEligibility` calls `ManualAttendanceService.checkAttendanceStartEligibility`.
4. After the lecture end time, the helper returns `afterEnd`.
5. `_loadManualAttendance` sets `_attendanceLoadError` to `انتهى وقت المحاضرة ولا يمكن بدء التحضير`, clears `_students`, and returns.
6. Because it returns early, `_attachSessionStream(ctx.sessionId)` is never called.
7. Existing records are not read, the fallback roster is not loaded, and export remains hidden because `_attendanceLoadError != null`.

The load-error UI then displays `تعذر تحميل بيانات التحضير` with the strict blocked message.

## 5. Root Cause

Confirmed root cause: the strict attendance-start guard was placed in the screen data-loading path, not only in write/start paths.

`LecturerAttendanceScreen._loadManualAttendance` blocks non-view-only loading before attaching the read-only record stream. This mixes two different behaviors:

- Start/create/write attendance eligibility.
- Read/view/report existing attendance data.

After the lecture has ended, the strict helper correctly rejects starting attendance. However, because `_loadManualAttendance` runs that check before `watchSessionRecords`, the screen also rejects report/list loading.

Confirmed non-root-cause: `ManualAttendanceService.watchSessionRecords`, `getSessionById`, `getSessionRawDataById`, and `getSessionsForSectionIds` are read paths and do not perform the strict start-time check.

## 6. Correct Behavior Separation

Read/view/report actions should be allowed after lecture end:

- Load an existing manual attendance session by id.
- Watch existing session records.
- Show student attendance rows.
- Show view-only attendance for ended/past lectures.
- Export an existing session report.
- Load the attendance report screen and report filters.

Start/create/write actions should remain strictly blocked outside the active lecture time:

- Creating or opening a manual attendance session for taking attendance.
- Saving manual attendance changes.
- Opening or refreshing QR attendance as a lecturer-start action.
- Opening NFC attendance as a lecturer-start action.
- Opening Bluetooth attendance as a lecturer-start action.
- Creating session documents through `prepareSessionForLecture`.

## 7. Recommended Fix

Keep the strict guard in service write/start paths, especially `ManualAttendanceService.prepareSessionForLecture`, because QR/NFC/Bluetooth creation routes depend on it.

Move the screen-level strict guard out of `LecturerAttendanceScreen._loadManualAttendance` so the screen can always resolve the session id and attach read-only data streams. Loading should not call `_attendanceStartEligibility` just to show existing data.

Recommended small fix:

- In `LecturerAttendanceScreen._loadManualAttendance`, remove or bypass the early `_attendanceStartEligibility` block.
- Let `_attachSessionStream(ctx.sessionId)` run for ended lectures.
- Keep `_saveChanges` guarded through `prepareSessionForLecture`.
- Keep QR/NFC/Bluetooth start actions guarded through their services and existing `LecturerAttendanceBlockedException` handling.
- If the screen is opened after end in editable mode, set a separate state such as `_attendanceStartEligibilityResult` or `_canEditAttendanceNow` and use it to disable start/edit controls, not to block loading.
- Consider forcing ended non-view-only sessions into a read-only presentation, or show an Arabic informational message above the table while still displaying records.

Do not reuse `_attendanceLoadError` for start-time eligibility failures unless a real read failure happened.

## 8. Suggested UI Messages

For read/report loading after the lecture has ended:

- `انتهى وقت المحاضرة. يمكنك عرض تقرير التحضير فقط.`

For blocked write/start attempts after the lecture has ended:

- `انتهى وقت المحاضرة ولا يمكن بدء التحضير.`

For blocked save attempts after the lecture has ended:

- `انتهى وقت المحاضرة ولا يمكن تعديل التحضير.`

For view-only existing records:

- `عرض فقط — لا يمكن تعديل الحضور.`

## 9. Test Cases Needed

| Test ID | Scenario | Expected Result |
| --- | --- | --- |
| RLG-01 | Open existing attendance session during active lecture time | Records load and editing/start controls are available |
| RLG-02 | Open existing attendance session after lecture end | Records load; no `تعذر تحميل بيانات التحضير` error |
| RLG-03 | Open existing attendance session after lecture end from report screen edit/open action | Records load in read-only or non-editable mode |
| RLG-04 | Save manual attendance after lecture end | Blocked with Arabic edit message |
| RLG-05 | Start QR after lecture end | Blocked; no QR/session write created |
| RLG-06 | Start NFC after lecture end | Blocked; no NFC/session write created |
| RLG-07 | Start Bluetooth after lecture end | Blocked; no Bluetooth/session write created |
| RLG-08 | Export existing session after lecture end | Export succeeds |
| RLG-09 | Open view-only attendance after lecture end | Records load and editing controls remain disabled |
| RLG-10 | Open report screen for ended lectures with no opened session | Existing default-present report policy still works |

## 10. Final Recommendation

The strict guard is currently blocking report/read loading in `lib/screens/lecturer/lecturer_attendance_screen.dart`, specifically inside `_loadManualAttendance` before record stream attachment.

Change `LecturerAttendanceScreen._loadManualAttendance` so read initialization always proceeds. Use strict eligibility only around attendance-start and write operations:

- Keep `ManualAttendanceService.prepareSessionForLecture` guarded.
- Keep `_saveChanges` guarded indirectly through `prepareSessionForLecture`.
- Keep QR/NFC/Bluetooth opening guarded through their services.
- Add UI state to disable or convert editing/start controls after end without setting `_attendanceLoadError`.

Implemented in the lecturer attendance screen by separating read initialization from attendance start/write eligibility.

## 11. Implementation Summary

Files changed:

- `lib/screens/lecturer/lecturer_attendance_screen.dart`
- `docs/lecturer_attendance_report_loading_regression.md`

Exact guard moved/bypassed:

- Removed the strict attendance-start guard from the initial `_loadManualAttendance` read path.
- `_loadManualAttendance` now resolves the session id, restores cache if available, attaches `watchSessionRecords`, and loads existing records without setting `_attendanceLoadError` just because the lecture ended.
- The strict eligibility check now refreshes separate UI state through `_refreshAttendanceStartEligibility` and is used to disable edit/start controls.

How report loading is now allowed after lecture end:

- Existing records can still be streamed through `ManualAttendanceService.watchSessionRecords`.
- Existing session data can be displayed even when the strict helper returns `afterEnd`.
- Ended lectures with no records suppress roster fallback and show `لا توجد بيانات تحضير مسجلة لهذه المحاضرة.` instead of `تعذر تحميل بيانات التحضير`.

How create/write/start actions remain blocked:

- `ManualAttendanceService.prepareSessionForLecture` remains strictly guarded.
- Manual save still calls `prepareSessionForLecture` before writing.
- QR, NFC, and Bluetooth start/open flows still route through guarded service paths.
- Status chips, save, QR activation, NFC activation, and Bluetooth opening/broadcast start are disabled outside the strict active window.

Arabic messages used:

- Report/read-only ended note: `انتهى وقت المحاضرة. يمكنك عرض تقرير التحضير فقط.`
- Blocked edit/save after end: `انتهى وقت المحاضرة ولا يمكن تعديل التحضير.`
- Blocked start/create after end remains: `انتهى وقت المحاضرة ولا يمكن بدء التحضير.`
- Ended no-records message: `لا توجد بيانات تحضير مسجلة لهذه المحاضرة.`

Manual verification:

- Code-path verification completed for the listed scenarios.
- Live emulator/device verification and Firestore no-write observation were not available in this environment.

Analyzer result:

```sh
flutter analyze
```

Result: failed with 32 existing unrelated warnings/infos. No analyzer issues were reported from `lib/screens/lecturer/lecturer_attendance_screen.dart` after this implementation.
