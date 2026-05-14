# Tasks: Add Comment Feature

## Implementation Steps

### 1. Create WorkoutSessionService
- [x] Create `entry/src/main/ets/common/services/WorkoutSessionService.ets`
- [x] Define `SavedSet`, `SavedExercise`, `WorkoutSession` interfaces
- [x] Implement singleton class with methods:
  - `saveSession(context, session)` — append session to preferences JSON array
  - `getSessions(context)` — retrieve all sessions
  - `getWeeklyStats(context)` — aggregate this week's count, duration, sets, volume
  - `getAllExerciseRecords(context)` — compute best 1RM per exercise from all sessions
- [x] Use store name `fit_tracker_sessions`, key `sessions`
- [x] Export as `export default new WorkoutSessionService()`

### 2. Add Notes Input to Workout Summary
- [x] Add `@State workoutNotes: string = ''` to WorkoutRecorderPage
- [x] In the summary build block (`if (this.showSummary)`), add a `TextArea` for notes input
  - Placeholder: "记录本次训练感受..." using `FontTokens.CAPTION_SIZE` and `ColorTokens.TEXT_DISABLED`
  - Styling: 80vp min height, SURFACE_PRIMARY background, SM border radius, MD margin between stats and button
- [x] Update `handleFinish()` to build `WorkoutSession` object from current state
- [x] Import and call `WorkoutSessionService.saveSession(getContext(this), session)` before navigating back
- [x] Change button text from "完成" to "保存训练"
- [x] Show a brief success toast/hint before navigation

### 3. Connect StatsPage to Real Data
- [x] Import `WorkoutSessionService` into StatsPage
- [x] Add `@State` fields for weekly stats: `weeklyCount`, `weeklyDuration`, `weeklySets`, `weeklyVolume`
- [x] In `aboutToAppear()`, call `WorkoutSessionService.getWeeklyStats()` and populate state fields
- [x] Replace hardcoded "0"/"0m"/"0kg" values with state-driven display
- [x] Format weekly duration as minutes (e.g., "45分钟")
- [x] Format weekly volume as "X kg"
- [x] For calendar heatmap, extract unique training dates from sessions and compute color intensity

### 4. Connect ExerciseDetailPage Real Records
- [x] Import `WorkoutSessionService` into ExerciseDetailPage
- [x] Add `@State best1RM: number = 0` and `@State bestRecord: { weight: number, reps: number, date: string } | null = null`
- [x] In `aboutToAppear()`, load exercise-specific records from `getAllExerciseRecords()`
- [x] Replace "尚未记录" with actual best 1RM and record details when data exists
- [x] Show "我的纪录" card with real values: best 1RM, best weight×reps detail, record date

### 5. Verification
- [ ] Complete a workout → verify notes are saved to preferences
- [ ] Verify StatsPage shows non-zero weekly stats after a session
- [ ] Verify ExerciseDetailPage shows personal record after a session involving that exercise
- [ ] Verify calendar heatmap shows colored cells for training days
