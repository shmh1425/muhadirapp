# Muhadir Gantt Chart

This chart is derived from commit activity between 2026-01-21 and 2026-06-01.

```mermaid
gantt
    title Muhadir Project Timeline
    dateFormat  YYYY-MM-DD
    axisFormat  %d %b

    section Foundation and Student Experience
    Project setup and Flutter baseline              :done, 2026-01-21, 1d
    Student auth, home, services, notifications     :done, 2026-01-21, 2026-01-28

    section Lecturer Module
    Lecturer home, navigation, calendar             :done, 2026-02-07, 2026-02-10
    Lecturer attendance, excuses, management        :done, 2026-02-16, 2026-02-20
    Manual attendance and Firestore integration     :done, 2026-03-12, 2026-03-13

    section Female Security Module
    Security screens and login flow                 :done, 2026-02-12, 2026-02-22
    Security Firestore integration                  :done, 2026-04-07, 2026-04-09
    Security localization and scan protections      :done, 2026-04-27, 2026-05-01

    section Firebase, Admin, and Academic Data
    Firebase configuration and student integration  :done, 2026-03-09, 1d
    Admin dashboard, courses, sections, timetable   :done, 2026-03-12, 2026-03-13
    Academic calendar and term exceptions           :done, 2026-04-05, 2026-04-07

    section Chatbot and Student Support
    MUHADIR chatbot and schedule link               :done, 2026-03-14, 2026-03-18
    Student excuses, absence summaries, translation :done, 2026-04-22, 2026-04-26
    Student absence UX and deep links               :done, 2026-05-21, 1d

    section Attendance Channels
    NFC attendance and card management              :done, 2026-04-23, 2026-05-04
    QR attendance validation and scanner flow       :done, 2026-04-27, 2026-05-05
    Bluetooth attendance flow                       :done, 2026-05-05, 2026-05-06

    section Reports, Export, and Lecturer Polish
    Attendance export service and report UI         :done, 2026-04-17, 2026-04-27
    Lecturer report/calendar alignment              :done, 2026-05-18, 2026-05-19
    Lecturer UI polish and localization             :done, 2026-04-30, 2026-05-19

    section Gate, Geo, and Release Readiness
    Gate QR verification and geofencing             :done, 2026-05-14, 2026-05-17
    iOS TestFlight prep and privacy entitlements    :done, 2026-05-15, 2026-05-17
    FCM, confidential display, security geo checks  :done, 2026-05-19, 1d

    section Theme and Visual Polish
    Theme persistence and dark mode preparation     :done, 2026-05-22, 2026-05-22
    Student and lecturer dark mode completion       :done, 2026-05-24, 2026-05-30

    section Offline Attendance Architecture
    Offline session and profile image phase         :done, 2026-05-20, 1d
    Offline engine, queue, processors               :done, 2026-05-26, 1d
    Unified attendance pipeline and UI state        :done, 2026-05-26, 1d
    Offline PR merge and Bluetooth lookup fix       :done, 2026-05-27, 1d
    Final student/offline polish                    :done, 2026-06-01, 1d
```

## Milestones

| Date | Milestone |
| --- | --- |
| 2026-01-21 | Project initialized and first student-facing shell created |
| 2026-02-22 | Female security feature merged into main history |
| 2026-03-13 | Admin data, sections, schedules, and lecturer manual attendance became active |
| 2026-04-17 | Attendance export work started |
| 2026-04-27 | Lecturer QR attendance session flow connected |
| 2026-05-06 | Bluetooth attendance flow reached submission support |
| 2026-05-17 | Gate, geo, and TestFlight readiness work completed for the sprint |
| 2026-05-27 | Offline attendance feature branch merged |
| 2026-06-01 | Student UI and offline attendance hardening polished |
