# Muhadir Meeting Minutes

These minutes are reconstructed from Git commit history. They summarize likely sprint discussions, decisions, and outcomes based on implementation evidence in commits from 2026-01-21 to 2026-06-01.

## Meeting 1 - Project Kickoff and Student Baseline

Date range: 2026-01-21 to 2026-01-28

Attendees from commit history: shmh1425, Eng-Aljazi

Agenda:
- Initialize the Muhadir Flutter project.
- Build splash, welcome, login, student home, services, settings, student card, and notifications.
- Prepare role folders and early QR/NFC attendance screens.

Decisions:
- Use Flutter as the main application platform.
- Start with a student-facing experience and shared student settings/state.
- Keep empty role folders for future role-based modules.

Outcomes:
- Initial project structure was committed.
- Student notifications were connected to the bell.
- Early services and home screen navigation were updated.

Action items:
- Continue role separation for lecturer and security flows.
- Clean project metadata for GitHub push.

## Meeting 2 - Lecturer Module Planning

Date range: 2026-02-07 to 2026-02-20

Attendees from commit history: AeshahDev, Eng-Aljazi, Ghala alqarni

Agenda:
- Add lecturer home, role-based navigation, calendar timeline, QR screen, and lecture management.
- Improve lecturer attendance and excuse management screens.

Decisions:
- Build lecturer workflows around calendar/timeline navigation.
- Add manage lectures, attendance, and excuse review as core lecturer capabilities.
- Continue aligning student schedule and excuse screens with navigation changes.

Outcomes:
- Lecturer home, calendar filters, timeline, navigation, QR, and manage lecture screens were added.
- Lecturer attendance and excuse management screens were introduced.

Action items:
- Connect lecturer data to Firestore.
- Improve attendance table readability and manual attendance behavior.

## Meeting 3 - Female Security Feature Merge

Date range: 2026-02-12 to 2026-02-22

Attendees from commit history: altugemiwdooh, Ghala alqarni, AeshahDev, Wadhuh Alturgemi, Aeshah Alsulami.

Agenda:
- Add female security login and screens.
- Implement accepted/rejected student flows and date picker.
- Merge female security feature work into main history.

Decisions:
- Female security should have its own role-specific screens and settings.
- Rejected student review and date filtering are needed for gate operations.

Outcomes:
- Female security screens, settings, gate/date UI, rejected student screen, and merge commits were completed.

Action items:
- Complete Firestore integration for accepted/rejected security records.
- Polish role navigation after merge.

## Meeting 4 - Firebase, Admin, and Timetable Data

Date range: 2026-03-09 to 2026-03-13

Attendees from commit history: Ghala alqarni, shmh1425, AeshahDev

Agenda:
- Add Firebase configuration.
- Integrate Firebase Auth and Firestore into student flow.
- Build admin dashboard and enhance course, lecturer, section, and timetable data.
- Complete lecturer manual attendance.

Decisions:
- Firestore will back student, course, lecturer, section, and attendance data.
- Course metadata should include major, college, department, Arabic course name, location, hall, and course type.
- Student schedules should be built from enrollments.

Outcomes:
- Firebase configuration and student Firestore integration were added.
- Admin course/section flows and student timetable generation were enhanced.
- Lecturer manual attendance functionality was completed.

Action items:
- Continue refining Firestore data integration.
- Validate lecturer attendance reports against term calendar data.

## Meeting 5 - Chatbot and Attendance Tracking

Date range: 2026-03-14 to 2026-03-18

Attendees from commit history: Eng-Aljazi, shmh1425

Agenda:
- Add MUHADIR AI chatbot, ChatFAB, API constants, and schedule links.
- Improve student schedule and attendance tracking filters.

Decisions:
- Chatbot should support student context and schedule navigation.
- Attendance tracking should support course tabs, week filtering, and absence percentage behavior.

Outcomes:
- MUHADIR chatbot was introduced and then upgraded.
- Attendance tracking gained course tabs, 15-week filtering, and course type support.

Action items:
- Refine chatbot copy and UI prompt style.
- Keep API constants local and out of public commits where needed.

## Meeting 6 - Academic Calendar and Security Firestore Integration

Date range: 2026-04-05 to 2026-04-09

Attendees from commit history: altugemiwdooh, shmh1425, Ghala alqarni, Eng-Aljazi

Agenda:
- Add academic terms, weeks, calendar exceptions, and admin Firestore debugging.
- Reflect academic calendar in lecturer flows and attendance reports.
- Connect female security accepted/rejected/verify dialogs to Firestore.

Decisions:
- Academic calendar data should drive lecturer workflows and attendance reports.
- Female security records should persist through Firestore.
- Delay/cancellation workflow should notify students.

Outcomes:
- Academic calendar and term data were added.
- Lecturer flows and attendance reports began using Firebase academic calendar data.
- Female security accepted, rejected, and verification actions were connected to Firestore.

Action items:
- Stabilize build issues and student notifications.
- Remove temporary security dialog test entry when no longer needed.

## Meeting 7 - Reports, Export, Excuses, and Translation

Date range: 2026-04-17 to 2026-04-26

Attendees from commit history: AeshahDev, shmh1425, Ghala alqarni, Eng-Aljazi

Agenda:
- Add attendance export service and lecturer export flow.
- Add lecturer excuse review flow and attachment support.
- Add translation layer, attendance summaries, chatbot absence report, and student excuse improvements.
- Implement NFC attendance and admin card management.

Decisions:
- Lecturer attendance reports should support export.
- Excuse review needs attachment preview, rejection dialog reuse, and attendance record synchronization.
- Student-facing absence language and translation consistency should be improved.

Outcomes:
- Export service, export UI, and manual attendance export data support were added.
- Lecturer excuse review and attachment features were implemented.
- Student excuses, translation, absence summaries, and NFC attendance/card management were improved.

Action items:
- Secure QR attendance Firestore access.
- Continue refining attendance reports and lecturer calendar alignment.

## Meeting 8 - QR Attendance and Attendance Policy

Date range: 2026-04-27 to 2026-04-29

Attendees from commit history: AeshahDev, altugemiwdooh, Eng-Aljazi, shmh1425

Agenda:
- Create QR attendance session model and service.
- Connect lecturer QR screen to active sessions.
- Add lecturer attendance method selector and student QR scanner flow.
- Unify attendance status policy and reflect QR attendance in reports/tracking.

Decisions:
- Attendance methods should be selectable by lecturers.
- QR attendance should be validated, secured through Firestore rules, and reflected in reports.
- Student notification badge and bottom navigation behavior should stay consistent across languages.

Outcomes:
- QR attendance validation, scanner flow, session connection, and attendance policy were implemented.
- Student notifications and English bottom navigation mirroring were improved.
- Female security duplicate scan prevention and localization were added.

Action items:
- Continue improving NFC and QR UX.
- Remove manual gate entry from security UI.

## Meeting 9 - NFC, Bluetooth, and Lecturer UI Polish

Date range: 2026-04-30 to 2026-05-06

Attendees from commit history: Ghala alqarni, shmh1425, altugemiwdooh, Eng-Aljazi, AeshahDev

Agenda:
- Improve lecturer attendance, reports, manage flows, and check-in UI.
- Refine NFC behavior on iOS and student/admin flows.
- Add rotating numeric codes to QR sessions.
- Add Bluetooth attendance model, service, lecturer flow, student placeholder, BLE foundation, and submission support.

Decisions:
- Attendance UX should support NFC, QR, numeric code, and Bluetooth flows.
- Lecturer attendance screens need compact tables and modern popups/bottom sheets.
- Bluetooth implementation should include both broadcast and scan controls.

Outcomes:
- Lecturer UI, NFC behavior, QR numeric code, and Bluetooth attendance capabilities were implemented.
- Student profile, notifications, titles, and wording were polished.

Action items:
- Stabilize iOS Bluetooth build and broadcast.
- Simplify lecturer Bluetooth controls after submission support.

## Meeting 10 - Performance, Gate, Geo, and Release Readiness

Date range: 2026-05-13 to 2026-05-19

Attendees from commit history: Eng-Aljazi, shomokh, shmh1425, Ghala alqarni, AeshahDev, Wadhuh Suliman Alturgemi

Agenda:
- Optimize student course loading, lecturer catalog loading, and security gate scan streaming.
- Implement QR verification and geofencing gate checks.
- Prepare iOS TestFlight builds and privacy entitlements.
- Add FCM messaging, confidential security display, and security gate geo-fence validation.
- Improve lecturer reports, localization, term-wide reporting, and absence metrics.

Decisions:
- Gate validation should combine QR/NFC parsing with geo policy checks.
- Notification infrastructure should register FCM device tokens.
- Lecturer attendance reports should be term-wide and localized.

Outcomes:
- Performance optimizations were merged.
- Gate QR verification, Android NFC gates, geo-fencing, digital ID, and TestFlight preparation were completed.
- Lecturer workflow/report polish and security notification/display work were completed.

Action items:
- Continue student excuse flow and chatbot absence UX.
- Polish dark mode and default theme behavior.

## Meeting 11 - Theme, Dark Mode, and Student UX

Date range: 2026-05-21 to 2026-05-30

Attendees from commit history: shmh1425, Wadhuh Suliman Alturgemi

Agenda:
- Improve student excuse flow, attendance deep-link, and chatbot absence UX.
- Add password recovery prototype dialog.
- Persist app theme mode and prepare screens for dark mode.
- Finish student and lecturer dark mode polish.

Decisions:
- App theme mode should persist between launches.
- First launch should default to light mode.
- Security photo upload should be disabled during this phase.

Outcomes:
- Student excuse/deep-link/chatbot absence improvements were added.
- Shared navigation, security, student, lecturer, login, digital ID, and excuse detail dark mode states were polished.
- Notification badge synchronization was fixed.

Action items:
- Continue validating color contrast across student and lecturer surfaces.
- Keep notification badge state synchronized with notification store.

## Meeting 12 - Offline Attendance Architecture

Date range: 2026-05-20 to 2026-06-01

Attendees from commit history: Eng-Aljazi, Wadhuh Suliman Alturgemi, shmh1425

Agenda:
- Add offline session support and profile images.
- Build offline engine core using Hive queue and sync.
- Add offline attendance processors for manual, NFC, QR, and Bluetooth channels.
- Unify attendance pipeline and event-driven UI state.
- Harden student offline attendance flow.

Decisions:
- Offline attendance should use a queue/sync engine and per-channel processors.
- Attendance pipeline should unify submission paths and UI state.
- Bluetooth offline enqueue and iOS BLE scan compatibility are required before merge.

Outcomes:
- Offline engine, processors, unified pipeline, and event-driven UI state were implemented.
- Offline attendance feature branch was merged.
- Bluetooth session lookup and student offline attendance flow were hardened.

Action items:
- Continue end-to-end testing of offline attendance recovery.
- Verify offline/online sync behavior across manual, NFC, QR, and Bluetooth attendance methods.
