# Design: Add Comment Feature

## Overview

Add a training notes input to the workout completion flow and persist complete workout sessions. This connects the training recorder to the stats and personal records features.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Workflow Changes                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Before:                                                │
│    End Training → Summary → [完成] → router.back()      │
│    (no data saved, stats always zero)                   │
│                                                         │
│  After:                                                 │
│    End Training → Summary + Notes Input → [保存]        │
│    → Save session via WorkoutSessionService             │
│    → router.back()                                      │
│    Stats & Records read from saved sessions             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Data Model

### WorkoutSession (persisted to preferences)

```typescript
interface SavedSet {
  weight: number   // kg
  reps: number
}

interface SavedExercise {
  name: string
  targetMuscle: string
  sets: SavedSet[]
}

interface WorkoutSession {
  id: string                    // unique ID (timestamp-based)
  planId: string                // associated plan ID
  planName: string              // plan name for display
  dayLabel: string              // training day label
  startTime: number             // timestamp ms
  endTime: number               // timestamp ms
  durationSeconds: number       // total duration
  totalSets: number             // completed sets with data
  totalVolume: number           // weight × reps sum
  notes: string                 // user training notes (NEW)
  exercises: SavedExercise[]    // all exercises with set data
  createdAt: string             // ISO date string for calendar lookups
}
```

### Storage

- Store name: `fit_tracker_sessions`
- Key: `sessions` — JSON stringified array of `WorkoutSession[]`
- Current user's data only (no multi-user isolation needed in local app)

## UI Design

### Summary Screen (Modified)

```
┌─────────────────────────────────┐
│         🎉 训练完成！           │
│                                 │
│    时长         组数            │
│   00:25:30       12            │
│                                 │
│   总容量：3240 kg               │
│                                 │
│  ┌─────────────────────────┐   │
│  │ 训练感受（可选）        │   │ ← NEW
│  │                         │   │
│  │ 今天状态很好，深蹲      │   │
│  │ 最后一组比较吃力...     │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┐   │
│  │       保存训练          │   │ ← Changed from "完成"
│  └─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘   │
└─────────────────────────────────┘
```

### Notes Input Specs
- `TextArea` with placeholder "记录本次训练感受..."
- Min height 80vp, max height 200vp, scrollable
- Optional — can be left empty
- Text color: TEXT_SECONDARY (placeholder), TEXT_PRIMARY (content)
- Background: SURFACE_PRIMARY with SM border radius

## Component Changes

### WorkoutSessionService (New)

Singleton service pattern, following existing conventions (AuthService, TrainingPlanService, etc.):

- `saveSession(context, session: WorkoutSession)` — append to stored array
- `getSessions(context): WorkoutSession[]` — retrieve all sessions
- `getSessionsByDate(context, date: string): WorkoutSession[]` — filter by date
- `getSessionsByDateRange(context, start: string, end: string): WorkoutSession[]` — range query
- `getWeeklyStats(context): { count, duration, sets, volume }` — aggregate for stats page
- `getAllExerciseRecords(context)` — build personal records from all sessions

### WorkoutRecorderPage Changes

1. Add `@State workoutNotes: string = ''` 
2. Modify summary build block: add notes TextArea before the save button
3. Modify handleFinish: build `WorkoutSession` object, call `WorkoutSessionService.saveSession()`, show confirmation

### StatsPage Changes

1. In `aboutToAppear`: load weekly stats from `WorkoutSessionService.getWeeklyStats()`
2. Replace hardcoded "0" values with actual loaded data
3. Calendar heatmap: color cells based on session dates

### ExerciseDetailPage Changes

1. In `aboutToAppear`: load personal records from `WorkoutSessionService.getAllExerciseRecords()`
2. Display actual best 1RM and record details instead of "尚未记录"

## Technical Decisions

### Why Preferences (not relational storage)?
- Consistent with existing architecture — all 5 services use `@ohos.data.preferences`
- Simple JSON array storage, no migration needed
- Appropriate for MVP with limited session count per user

### Why save all set data?
- Enables personal records calculation across sessions
- Allows future features: workout history detail view, exercise progress graphs
- JSON is lightweight for this data volume

### Notes field sizing
- Max 500 characters (informal limit, no hard enforcement)
- Saved as plain text, no markdown rendering needed at this stage
