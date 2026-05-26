# Attendance Pipeline Architecture (Frozen — Phase 3.6)

This document is the authoritative reference for the Muhadir attendance system after Phase 2B (Offline Engine), Phase 3 (Unified Pipeline), Phase 3.5 (Event-Driven UI State), and Phase 3.6 (Contract Freeze).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ UI (screens) — rendering only                                    │
│   LecturerAttendanceScreen / NfcAttendanceScreen                 │
│   → AttendanceEntryPoint.submit()                               │
│   → AttendanceStateService.attendanceStateEvents (listen)        │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│ Phase 3 — Unified Attendance Pipeline                            │
│   AttendanceEntryPoint → AttendanceSubmissionRouter              │
│   → AttendanceUnifiedService                                     │
│       ├─ QR (online only) → delegates → legacy Firestore services│
│       └─ NFC/BT/Manual → online try → AttendanceOfflineBridge    │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│ Phase 2B — Offline Engine (UNCHANGED core)                       │
│   OfflineQueueService (Hive) + OfflineSyncEngine                 │
│   Processors: Manual / NFC / Bluetooth                           │
│   OfflineAttendanceSignals → AttendanceStateService              │
└─────────────────────────────────────────────────────────────────┘
```

## Layer Responsibilities

| Layer | Responsibility | Violation examples |
|-------|----------------|-------------------|
| **UI** | Render; call `AttendanceEntryPoint`; listen to `AttendanceStateService` | Direct `OfflineQueueService`, Firestore writes |
| **EntryPoint** | Idempotency window; single public submit API | Enqueue, connectivity checks |
| **SubmissionRouter** | Build `AttendancePayload` contract | Firestore / queue access |
| **UnifiedService** | Route: QR online-only vs offline-capable | UI state, polling |
| **OfflineBridge** | Enqueue with `AttendanceOperationIdentity` | Direct processor calls |
| **OfflineEngine** | Sync lifecycle, retry, Hive persistence | UI updates |
| **Processor** | Replay queued op → legacy Firestore service | UI, dedup policy in UI |
| **StateService** | Live UI state from queue snapshot + signals | Business writes |
| **PureResolver** | Pure functions: snapshot → `AttendanceUIState` | Side effects, caching |

## Frozen Contracts (`lib/features/attendance/contracts/`)

### Submission — `AttendanceSubmissionContract`

Implemented by `AttendancePayload`. All channels (NFC, BLE, QR, Manual) normalize into:

- `sessionId`, `studentId`, `courseId`, `source`, `timestamp`, `requestId`

### Sync — `AttendanceSyncContract`

View type: `OfflineOperationSyncView` over `OfflineOperation`. Processors and sync engine use operation identity via `AttendanceOperationIdentity` — not ad-hoc map keys in UI.

### UI — `AttendanceUiContract` / `AttendanceUiStatus`

Screens must use `AttendanceStateService.uiContractFor()` or `attendanceStateEvents` — never read queue or runtime syncing IDs.

## Operation Identity (`AttendanceOperationIdentity`)

**Single builder for dedup keys:**

- `buildOperationKey(sessionId, studentId, source, attendanceStatus)`
- `buildSyncIdentity(operationId, operationKey?)`
- `normalizeAttendanceIdentity(payload)`
- `embedInPayload(payload)`

`ManualAttendanceOperationKey` is **deprecated** and forwards here.

Dedup format: `{sessionId}_{studentId}_{source}_{status}`

## Attendance Pipeline (Submit)

```
UI.submit()
  → AttendanceEntryPoint (idempotency cache, 30s TTL)
  → AttendanceSubmissionRouter (AttendancePayload)
  → AttendanceUnifiedService
       if QR:
         if offline → reject (FAIL FAST)
         else → AttendanceQrOnlineDelegate → QrAttendanceService
       else (NFC/BT/Manual-capable):
         try online delegate → legacy service
         on business exception → rethrow to UI
         on transient failure → AttendanceOfflineBridge.enqueue
         → OfflineSyncEngine.runStartupSyncSequence (background)
```

## Queue Lifecycle

```
enqueue → status=pending → signal(operationChanged)
sync start → beginRuntimeSync → signal(runtimeSyncStarted) → UI=syncing
success → markSynced → removeOperation → signal(operationRemoved) → UI=synced
failure → markFailed or markRetryPending → signal(operationChanged)
```

Statuses: `pending | syncing (runtime only) | synced | failed`

## State Resolution Flow (Event-Driven)

```
OfflineAttendanceSignals
  → AttendanceStateService._onOfflineSignal
  → read AttendanceQueueSnapshot (one read)
  → AttendanceStatePureResolver.resolveUiModel(...)
  → diff → AttendanceStateEvent → notifyListeners
```

**No polling.** Updates only on signals or `notifyPipelineOutcome` (optimistic).

## Runtime Sync Flow

- `OfflineQueueService.beginRuntimeSync(id)` / `endRuntimeSync(id)` track in-memory syncing set.
- Not persisted as `syncing` in Hive (recovered to `pending` on startup).
- UI `syncing` state = operation in unsynced list AND id in `runtimeSyncingOperationIds`.

## Processor Registration

Registered in `OfflineEngineBootstrap.initializeInfrastructure()`:

1. `ManualAttendanceProcessor`
2. `NfcAttendanceProcessor`
3. `BluetoothAttendanceProcessor`

> **Future (out of scope):** Lazy processor registration (Phase 4 scaling).

## Event Flow

| Signal | UI event |
|--------|----------|
| enqueue / pending | `enqueued` |
| runtime sync start | `syncing` |
| remove after success | `synced` |
| failed status | `failed` |

## Dedup Rules

- Queue coalesces by `operationKey` from `AttendanceOperationIdentity`.
- Entry-level idempotency: `requestId` cache (short TTL).
- Sync engine: in-flight dedup by `operationKey` and `operationId`.

## Retry Rules

- Max retries: `OfflineSyncFailurePolicy.defaultMaxRetries` (3).
- Transient failures → `markRetryPending` with exponential backoff (max 30s).
- Permanent failures → `markFailed`.
- Startup: `runStartupSyncSequence` — drain, requeue retriable failed, drain again.

## Failure Handling

- Business errors (`NfcAttendanceException`, etc.) → propagate to UI (not queued).
- Network/Firestore transient → queue + retry.
- QR offline → rejected at UnifiedService (never enqueued).

## UI State Rules

- Source of truth: **Offline queue snapshot + runtime sync set**.
- Firestore overlay for manual lecturer view via `firestoreMapBuilder` on session attach.
- `AttendanceUIState` (legacy enum) maps to frozen `AttendanceUiStatus` via `AttendanceUiContract`.

## Logging

Unified categories: `AttendanceLogCategories` (`OFFLINE_ENGINE`, `QUEUE`, `SYNC`, `STATE`, `UI`, `ERROR`, pipeline channels).

Legacy wrappers: `AttendancePipelineLogger`, `AttendanceUiStateLogger`, `OfflineEngineLog` (aliases preserved).

## Channel Matrix

| Channel | Offline queue | Online path |
|---------|---------------|-------------|
| NFC | Yes | `NfcAttendanceService` |
| Bluetooth | Yes | `BluetoothAttendanceService` |
| Manual (lecturer batch) | Yes | `ManualAttendanceOfflineService` |
| QR | **No** | `QrAttendanceService` only |

## Technical Debt (Known)

- Lecturer screen still maps `AttendanceUIState` on `_StudentRow` (internal model); prefer `AttendanceUiContract` in new code.
- Student NFC screen uses stream + local `_selfAttendanceUiState` duplicate for banner (acceptable; driven by events).
- `AttendanceStateService` is a process-wide singleton; tests should inject queue mock via constructor.
- Processor registration is eager at bootstrap (lazy registration deferred).

## Phase Integrity Checklist

- Phase 2B Offline Engine: **unchanged architecture** (signals added, no schema/queue structure change).
- Phase 3 Pipeline: **intact** (EntryPoint → Router → UnifiedService).
- Phase 3.5: **no polling**; event-driven state preserved.
- Phase 3.6: **contracts frozen**; identity centralized; docs + logging standardized.
