# FitTracker Clean ArkUI Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Initialize a clean feature-first ArkUI skeleton for the target training loop while preserving the existing app code as reference.

**Architecture:** Add new `app`, `features`, `shared`, and `mock` modules under `entry/src/main/ets`. New code uses local-first typed models, seed content, repository/service contracts, placeholder pages, and route registration. Existing pages and services remain in place until the new skeleton can replace them safely.

**Tech Stack:** HarmonyOS Stage Mode, ArkTS/ArkUI, `@kit.ArkData` preferences, `@kit.ArkUI` router, Hypium-style tests where available.

---

## File Structure

Create these new files:

- `entry/src/main/ets/shared/models/TrainingModels.ets`: shared interfaces and factory functions for goals, exercises, plans, workouts, records, content version, and sync status.
- `entry/src/main/ets/mock/SeedMuscles.ets`: typed seed muscle groups.
- `entry/src/main/ets/mock/SeedEquipment.ets`: typed seed equipment list.
- `entry/src/main/ets/mock/SeedExercises.ets`: typed seed exercises with alternatives.
- `entry/src/main/ets/mock/SeedPlanRules.ets`: typed seed plan rules.
- `entry/src/main/ets/shared/services/ContentRepository.ets`: local content read API over seed content.
- `entry/src/main/ets/shared/services/PlanEngine.ets`: rule-based minimal training plan generator.
- `entry/src/main/ets/shared/services/ReviewService.ets`: local training calculations.
- `entry/src/main/ets/shared/services/SyncService.ets`: placeholder local content sync status.
- `entry/src/main/ets/shared/services/WorkoutRepository.ets`: minimal local workout save/read contract.
- `entry/src/main/ets/app/AppRoutes.ets`: route constants for the new skeleton.
- `entry/src/main/ets/app/AppState.ets`: startup decision helpers and store names.
- `entry/src/main/ets/app/StartupPage.ets`: initial page for the new flow.
- `entry/src/main/ets/pages/HomePage.ets`: new target-loop home placeholder.
- `entry/src/main/ets/features/onboarding/pages/GoalSetupPage.ets`: goal setup placeholder.
- `entry/src/main/ets/features/planner/pages/PlanHomePage.ets`: plan overview placeholder.
- `entry/src/main/ets/features/planner/pages/PlanDayDetailPage.ets`: plan day placeholder.
- `entry/src/main/ets/features/exercise/pages/ExerciseHomePage.ets`: muscle map placeholder.
- `entry/src/main/ets/features/exercise/pages/ExerciseListPage.ets`: exercise list placeholder.
- `entry/src/main/ets/features/exercise/pages/ExerciseDetailPage.ets`: exercise detail placeholder.
- `entry/src/main/ets/features/workout/pages/WorkoutPreviewPage.ets`: workout preview placeholder.
- `entry/src/main/ets/features/workout/pages/ActiveWorkoutPage.ets`: active workout placeholder.
- `entry/src/main/ets/features/workout/pages/WorkoutSummaryPage.ets`: workout summary placeholder.
- `entry/src/main/ets/features/review/pages/ReviewHomePage.ets`: review dashboard placeholder.
- `entry/src/main/ets/features/review/pages/MuscleCoveragePage.ets`: muscle coverage placeholder.
- `entry/src/main/ets/features/review/pages/PersonalRecordsPage.ets`: records placeholder.
- `entry/src/main/ets/features/profile/pages/ProfileHomePage.ets`: profile placeholder.
- `entry/src/main/ets/features/profile/pages/ContentSyncPage.ets`: content sync placeholder.
- `entry/src/test/TargetLoopSkeleton.test.ets`: lightweight tests for seed data, plan generation, and review calculations.

Modify:

- `entry/src/main/resources/base/profile/main_pages.json`: append new route entries while keeping old routes.
- `docs/项目重新初始化方案.md`: update completion notes after implementation if needed.

Do not modify or delete:

- Existing `entry/src/main/ets/pages/*.ets` files unless a task explicitly says to append routes only.
- Existing `entry/src/main/ets/common/services/*.ets`.
- Existing design token files in this phase.

## Validation Commands

Use available commands in this order:

```powershell
git diff --check
```

Expected: exit code 0, only CRLF warnings are acceptable.

```powershell
hvigorw assembleHap --mode module -p product=default
```

Expected: build succeeds. If DevEco/Hvigor is unavailable in the environment, record the exact failure and run static checks instead.

---

### Task 1: Shared Data Models

**Files:**
- Create: `entry/src/main/ets/shared/models/TrainingModels.ets`
- Test: `entry/src/test/TargetLoopSkeleton.test.ets`

- [ ] **Step 1: Write failing model factory tests**

Create `entry/src/test/TargetLoopSkeleton.test.ets` with:

```typescript
import { describe, it, expect } from '@ohos/hypium'
import {
  createUserGoal,
  createExerciseContent,
  createWorkoutSet,
  estimateOneRepMax
} from '../main/ets/shared/models/TrainingModels'

export default function targetLoopSkeletonTest() {
  describe('TargetLoop models', () => {
    it('creates a typed user goal', 0, () => {
      const equipmentIds: string[] = ['eq_dumbbell']
      const restrictedMuscleIds: string[] = ['muscle_knee_sensitive']
      const goal = createUserGoal('goal_1', 'hypertrophy', 'beginner', 3, 60, equipmentIds, restrictedMuscleIds, 1000, 1000)
      expect(goal.goalId).assertEqual('goal_1')
      expect(goal.weeklyDays).assertEqual(3)
      expect(goal.equipmentIds.length).assertEqual(1)
    })

    it('creates typed exercise content', 0, () => {
      const aliases: string[] = ['bench']
      const primaryMuscleIds: string[] = ['muscle_chest']
      const secondaryMuscleIds: string[] = ['muscle_triceps']
      const equipmentIds: string[] = ['eq_barbell']
      const goalTags: string[] = ['hypertrophy']
      const steps: string[] = ['Set shoulders', 'Press the bar']
      const cues: string[] = ['Keep wrist neutral']
      const commonMistakes: string[] = ['Flaring elbows']
      const safetyNotes: string[] = ['Use a spotter']
      const alternativeExerciseIds: string[] = ['ex_dumbbell_press']
      const ex = createExerciseContent(
        'ex_barbell_bench_press',
        'barbell bench press',
        'Barbell Bench Press',
        aliases,
        primaryMuscleIds,
        secondaryMuscleIds,
        equipmentIds,
        'intermediate',
        goalTags,
        '',
        '',
        steps,
        cues,
        commonMistakes,
        safetyNotes,
        alternativeExerciseIds,
        1
      )
      expect(ex.exerciseId).assertEqual('ex_barbell_bench_press')
      expect(ex.primaryMuscleIds[0]).assertEqual('muscle_chest')
    })

    it('estimates one rep max with Epley formula', 0, () => {
      const set = createWorkoutSet('set_1', 'ex_barbell_bench_press', 100, 5, 8, false)
      expect(estimateOneRepMax(set.weight, set.reps)).assertEqual(116.67)
    })
  })
}
```

- [ ] **Step 2: Run test to verify imports fail**

Run:

```powershell
hvigorw assembleHap --mode module -p product=default
```

Expected: FAIL because `../main/ets/shared/models/TrainingModels` does not exist.

- [ ] **Step 3: Create model interfaces and factories**

Create `entry/src/main/ets/shared/models/TrainingModels.ets`:

```typescript
/**
 * TrainingModels - shared target-loop data contracts.
 */

export interface UserGoal {
  goalId: string
  goalType: string
  level: string
  weeklyDays: number
  sessionMinutes: number
  equipmentIds: string[]
  restrictedMuscleIds: string[]
  createdAt: number
  updatedAt: number
}

export interface MuscleGroup {
  muscleId: string
  nameZh: string
  region: string
}

export interface EquipmentItem {
  equipmentId: string
  nameZh: string
}

export interface ExerciseContent {
  exerciseId: string
  nameZh: string
  nameEn: string
  aliases: string[]
  primaryMuscleIds: string[]
  secondaryMuscleIds: string[]
  equipmentIds: string[]
  difficulty: string
  goalTags: string[]
  videoUrl: string
  coverUrl: string
  steps: string[]
  cues: string[]
  commonMistakes: string[]
  safetyNotes: string[]
  alternativeExerciseIds: string[]
  contentVersion: number
}

export interface PlannedExercise {
  plannedExerciseId: string
  exerciseId: string
  targetSets: number
  targetReps: string
  intensityNote: string
  alternativeExerciseIds: string[]
}

export interface PlanDay {
  dayId: string
  dayOfWeek: number
  title: string
  focusMuscleIds: string[]
  exercises: PlannedExercise[]
}

export interface TrainingPlan {
  planId: string
  goalId: string
  name: string
  cycleWeeks: number
  days: PlanDay[]
  generatedBy: string
  status: string
}

export interface WorkoutSet {
  setId: string
  exerciseId: string
  weight: number
  reps: number
  rpe: number
  isWarmup: boolean
}

export interface WorkoutSession {
  sessionId: string
  planId: string
  dayId: string
  startedAt: number
  endedAt: number
  durationSeconds: number
  totalSets: number
  totalVolume: number
  fatigueScore: number
  notes: string
  sets: WorkoutSet[]
}

export interface ContentSyncStatus {
  localVersion: number
  remoteVersion: number
  lastCheckedAt: number
  status: string
}

export function createUserGoal(
  goalId: string,
  goalType: string,
  level: string,
  weeklyDays: number,
  sessionMinutes: number,
  equipmentIds: string[],
  restrictedMuscleIds: string[],
  createdAt: number,
  updatedAt: number
): UserGoal {
  const item: UserGoal = {
    goalId: goalId,
    goalType: goalType,
    level: level,
    weeklyDays: weeklyDays,
    sessionMinutes: sessionMinutes,
    equipmentIds: equipmentIds,
    restrictedMuscleIds: restrictedMuscleIds,
    createdAt: createdAt,
    updatedAt: updatedAt
  }
  return item
}

export function createMuscleGroup(muscleId: string, nameZh: string, region: string): MuscleGroup {
  const item: MuscleGroup = {
    muscleId: muscleId,
    nameZh: nameZh,
    region: region
  }
  return item
}

export function createEquipmentItem(equipmentId: string, nameZh: string): EquipmentItem {
  const item: EquipmentItem = {
    equipmentId: equipmentId,
    nameZh: nameZh
  }
  return item
}

export function createExerciseContent(
  exerciseId: string,
  nameZh: string,
  nameEn: string,
  aliases: string[],
  primaryMuscleIds: string[],
  secondaryMuscleIds: string[],
  equipmentIds: string[],
  difficulty: string,
  goalTags: string[],
  videoUrl: string,
  coverUrl: string,
  steps: string[],
  cues: string[],
  commonMistakes: string[],
  safetyNotes: string[],
  alternativeExerciseIds: string[],
  contentVersion: number
): ExerciseContent {
  const item: ExerciseContent = {
    exerciseId: exerciseId,
    nameZh: nameZh,
    nameEn: nameEn,
    aliases: aliases,
    primaryMuscleIds: primaryMuscleIds,
    secondaryMuscleIds: secondaryMuscleIds,
    equipmentIds: equipmentIds,
    difficulty: difficulty,
    goalTags: goalTags,
    videoUrl: videoUrl,
    coverUrl: coverUrl,
    steps: steps,
    cues: cues,
    commonMistakes: commonMistakes,
    safetyNotes: safetyNotes,
    alternativeExerciseIds: alternativeExerciseIds,
    contentVersion: contentVersion
  }
  return item
}

export function createPlannedExercise(
  plannedExerciseId: string,
  exerciseId: string,
  targetSets: number,
  targetReps: string,
  intensityNote: string,
  alternativeExerciseIds: string[]
): PlannedExercise {
  const item: PlannedExercise = {
    plannedExerciseId: plannedExerciseId,
    exerciseId: exerciseId,
    targetSets: targetSets,
    targetReps: targetReps,
    intensityNote: intensityNote,
    alternativeExerciseIds: alternativeExerciseIds
  }
  return item
}

export function createPlanDay(
  dayId: string,
  dayOfWeek: number,
  title: string,
  focusMuscleIds: string[],
  exercises: PlannedExercise[]
): PlanDay {
  const item: PlanDay = {
    dayId: dayId,
    dayOfWeek: dayOfWeek,
    title: title,
    focusMuscleIds: focusMuscleIds,
    exercises: exercises
  }
  return item
}

export function createTrainingPlan(
  planId: string,
  goalId: string,
  name: string,
  cycleWeeks: number,
  days: PlanDay[],
  generatedBy: string,
  status: string
): TrainingPlan {
  const item: TrainingPlan = {
    planId: planId,
    goalId: goalId,
    name: name,
    cycleWeeks: cycleWeeks,
    days: days,
    generatedBy: generatedBy,
    status: status
  }
  return item
}

export function createWorkoutSet(
  setId: string,
  exerciseId: string,
  weight: number,
  reps: number,
  rpe: number,
  isWarmup: boolean
): WorkoutSet {
  const item: WorkoutSet = {
    setId: setId,
    exerciseId: exerciseId,
    weight: weight,
    reps: reps,
    rpe: rpe,
    isWarmup: isWarmup
  }
  return item
}

export function createWorkoutSession(
  sessionId: string,
  planId: string,
  dayId: string,
  startedAt: number,
  endedAt: number,
  durationSeconds: number,
  totalSets: number,
  totalVolume: number,
  fatigueScore: number,
  notes: string,
  sets: WorkoutSet[]
): WorkoutSession {
  const item: WorkoutSession = {
    sessionId: sessionId,
    planId: planId,
    dayId: dayId,
    startedAt: startedAt,
    endedAt: endedAt,
    durationSeconds: durationSeconds,
    totalSets: totalSets,
    totalVolume: totalVolume,
    fatigueScore: fatigueScore,
    notes: notes,
    sets: sets
  }
  return item
}

export function createContentSyncStatus(
  localVersion: number,
  remoteVersion: number,
  lastCheckedAt: number,
  status: string
): ContentSyncStatus {
  const item: ContentSyncStatus = {
    localVersion: localVersion,
    remoteVersion: remoteVersion,
    lastCheckedAt: lastCheckedAt,
    status: status
  }
  return item
}

export function estimateOneRepMax(weight: number, reps: number): number {
  const raw = weight * (1 + reps / 30)
  return Math.round(raw * 100) / 100
}
```

- [ ] **Step 4: Run validation**

Run:

```powershell
hvigorw assembleHap --mode module -p product=default
```

Expected: model import errors are resolved. The build may fail later due to existing unrelated code; record the first remaining error.

- [ ] **Step 5: Commit**

```powershell
git add entry/src/main/ets/shared/models/TrainingModels.ets entry/src/test/TargetLoopSkeleton.test.ets
git commit -m "feat: add target loop shared models"
```

---

### Task 2: Seed Content and Content Repository

**Files:**
- Create: `entry/src/main/ets/mock/SeedMuscles.ets`
- Create: `entry/src/main/ets/mock/SeedEquipment.ets`
- Create: `entry/src/main/ets/mock/SeedExercises.ets`
- Create: `entry/src/main/ets/shared/services/ContentRepository.ets`
- Modify: `entry/src/test/TargetLoopSkeleton.test.ets`

- [ ] **Step 1: Extend failing tests for content repository**

Append inside `targetLoopSkeletonTest()` after the existing `describe` block:

```typescript
  describe('ContentRepository seed content', () => {
    it('returns seed muscles and equipment', 0, () => {
      const muscles = ContentRepository.getMuscles()
      const equipment = ContentRepository.getEquipment()
      expect(muscles.length).assertEqual(6)
      expect(equipment.length).assertEqual(6)
    })

    it('finds alternatives for an exercise', 0, () => {
      const alternatives = ContentRepository.getAlternativeExercises('ex_barbell_bench_press')
      expect(alternatives.length).assertLarger(0)
      expect(alternatives[0].exerciseId).assertEqual('ex_dumbbell_bench_press')
    })
  })
```

Add this import at the top:

```typescript
import ContentRepository from '../main/ets/shared/services/ContentRepository'
```

- [ ] **Step 2: Run test to verify repository import fails**

Run:

```powershell
hvigorw assembleHap --mode module -p product=default
```

Expected: FAIL because `ContentRepository` does not exist.

- [ ] **Step 3: Create seed muscles**

Create `entry/src/main/ets/mock/SeedMuscles.ets`:

```typescript
/**
 * SeedMuscles - first-party muscle seed content.
 */
import { MuscleGroup, createMuscleGroup } from '../shared/models/TrainingModels'

export const SEED_MUSCLES: MuscleGroup[] = [
  createMuscleGroup('muscle_chest', '胸部', 'front'),
  createMuscleGroup('muscle_back', '背部', 'back'),
  createMuscleGroup('muscle_legs', '腿部', 'lower'),
  createMuscleGroup('muscle_shoulders', '肩部', 'upper'),
  createMuscleGroup('muscle_arms', '手臂', 'upper'),
  createMuscleGroup('muscle_core', '核心', 'front')
]
```

- [ ] **Step 4: Create seed equipment**

Create `entry/src/main/ets/mock/SeedEquipment.ets`:

```typescript
/**
 * SeedEquipment - first-party equipment seed content.
 */
import { EquipmentItem, createEquipmentItem } from '../shared/models/TrainingModels'

export const SEED_EQUIPMENT: EquipmentItem[] = [
  createEquipmentItem('eq_barbell', '杠铃'),
  createEquipmentItem('eq_dumbbell', '哑铃'),
  createEquipmentItem('eq_cable', '绳索'),
  createEquipmentItem('eq_machine', '固定器械'),
  createEquipmentItem('eq_bodyweight', '自重'),
  createEquipmentItem('eq_band', '弹力带')
]
```

- [ ] **Step 5: Create seed exercises**

Create `entry/src/main/ets/mock/SeedExercises.ets`:

```typescript
/**
 * SeedExercises - first-party exercise seed content.
 */
import { ExerciseContent, createExerciseContent } from '../shared/models/TrainingModels'

export const SEED_EXERCISES: ExerciseContent[] = [
  createExerciseContent('ex_barbell_bench_press', '杠铃卧推', 'Barbell Bench Press', ['卧推'], ['muscle_chest'], ['muscle_arms', 'muscle_shoulders'], ['eq_barbell'], 'intermediate', ['hypertrophy', 'strength'], '', '', ['肩胛后缩并下沉', '杠铃下降到胸中下部', '推起时保持手腕中立'], ['保持胸椎稳定'], ['肘部过度外展'], ['建议使用保护架或保护者'], ['ex_dumbbell_bench_press'], 1),
  createExerciseContent('ex_dumbbell_bench_press', '哑铃卧推', 'Dumbbell Bench Press', ['哑铃推胸'], ['muscle_chest'], ['muscle_arms', 'muscle_shoulders'], ['eq_dumbbell'], 'beginner', ['hypertrophy'], '', '', ['哑铃位于胸侧', '向上推起并控制下降'], ['左右手保持同步'], ['下降过深导致肩部不适'], ['肩痛时减少活动幅度'], ['ex_push_up'], 1),
  createExerciseContent('ex_push_up', '俯卧撑', 'Push Up', ['push up'], ['muscle_chest'], ['muscle_arms', 'muscle_core'], ['eq_bodyweight'], 'beginner', ['hypertrophy', 'fat_loss'], '', '', ['身体保持直线', '胸部接近地面后推起'], ['收紧核心'], ['塌腰'], ['手腕不适时使用支撑把'], ['ex_dumbbell_bench_press'], 1),
  createExerciseContent('ex_pull_up', '引体向上', 'Pull Up', ['引体'], ['muscle_back'], ['muscle_arms'], ['eq_bodyweight'], 'intermediate', ['hypertrophy', 'strength'], '', '', ['握紧横杠', '肩胛下沉后拉起'], ['避免借力摆动'], ['耸肩发力'], ['肩部疼痛时改用下拉'], ['ex_lat_pulldown'], 1),
  createExerciseContent('ex_lat_pulldown', '高位下拉', 'Lat Pulldown', ['下拉'], ['muscle_back'], ['muscle_arms'], ['eq_cable', 'eq_machine'], 'beginner', ['hypertrophy'], '', '', ['坐稳并固定大腿', '把手下拉到锁骨附近'], ['用背部发力'], ['身体后仰过多'], ['控制重量避免肩部拉扯'], ['ex_pull_up'], 1),
  createExerciseContent('ex_barbell_squat', '杠铃深蹲', 'Barbell Squat', ['深蹲'], ['muscle_legs'], ['muscle_core'], ['eq_barbell'], 'intermediate', ['hypertrophy', 'strength'], '', '', ['站距略宽于肩', '髋膝同时屈曲', '稳定站起'], ['膝盖方向跟随脚尖'], ['膝盖内扣'], ['腰背不适时降低重量'], ['ex_leg_press'], 1),
  createExerciseContent('ex_leg_press', '腿举', 'Leg Press', ['倒蹬'], ['muscle_legs'], [], ['eq_machine'], 'beginner', ['hypertrophy'], '', '', ['脚放在踏板中部', '控制下降', '蹬起不锁死膝盖'], ['保持下背贴合靠垫'], ['膝盖完全锁死'], ['膝痛时缩短幅度'], ['ex_barbell_squat'], 1),
  createExerciseContent('ex_dumbbell_shoulder_press', '哑铃肩推', 'Dumbbell Shoulder Press', ['肩推'], ['muscle_shoulders'], ['muscle_arms'], ['eq_dumbbell'], 'beginner', ['hypertrophy'], '', '', ['哑铃位于肩侧', '向上推起', '控制下降'], ['核心收紧'], ['腰部过度反弓'], ['肩痛时改小重量'], ['ex_lateral_raise'], 1),
  createExerciseContent('ex_lateral_raise', '哑铃侧平举', 'Dumbbell Lateral Raise', ['侧平举'], ['muscle_shoulders'], [], ['eq_dumbbell'], 'beginner', ['hypertrophy'], '', '', ['手肘微屈', '抬至肩高', '慢速下降'], ['用肩中束带动'], ['耸肩借力'], ['避免过重'], ['ex_dumbbell_shoulder_press'], 1),
  createExerciseContent('ex_plank', '平板支撑', 'Plank', ['plank'], ['muscle_core'], ['muscle_shoulders'], ['eq_bodyweight'], 'beginner', ['fat_loss', 'posture'], '', '', ['前臂支撑', '身体保持直线', '均匀呼吸'], ['收紧臀部和腹部'], ['塌腰'], ['腰痛时缩短时间'], ['ex_dead_bug'], 1),
  createExerciseContent('ex_dead_bug', '死虫', 'Dead Bug', ['dead bug'], ['muscle_core'], [], ['eq_bodyweight'], 'beginner', ['posture'], '', '', ['仰卧抬手抬腿', '对侧手脚缓慢伸展', '回到起始位置'], ['腰背贴地'], ['动作过快'], ['腰痛时减小幅度'], ['ex_plank'], 1)
]
```

- [ ] **Step 6: Create ContentRepository**

Create `entry/src/main/ets/shared/services/ContentRepository.ets`:

```typescript
/**
 * ContentRepository - local-first exercise content access.
 */
import { ExerciseContent, MuscleGroup, EquipmentItem } from '../models/TrainingModels'
import { SEED_MUSCLES } from '../../mock/SeedMuscles'
import { SEED_EQUIPMENT } from '../../mock/SeedEquipment'
import { SEED_EXERCISES } from '../../mock/SeedExercises'

class ContentRepository {
  getMuscles(): MuscleGroup[] {
    return SEED_MUSCLES
  }

  getEquipment(): EquipmentItem[] {
    return SEED_EQUIPMENT
  }

  getExercises(): ExerciseContent[] {
    return SEED_EXERCISES
  }

  getExerciseById(exerciseId: string): ExerciseContent | undefined {
    return SEED_EXERCISES.find((item: ExerciseContent) => item.exerciseId === exerciseId)
  }

  getExercisesByMuscle(muscleId: string): ExerciseContent[] {
    return SEED_EXERCISES.filter((item: ExerciseContent) => item.primaryMuscleIds.includes(muscleId))
  }

  getExercisesByEquipment(equipmentId: string): ExerciseContent[] {
    return SEED_EXERCISES.filter((item: ExerciseContent) => item.equipmentIds.includes(equipmentId))
  }

  searchExercises(query: string): ExerciseContent[] {
    const keyword = query.trim().toLowerCase()
    if (keyword.length === 0) {
      return SEED_EXERCISES
    }
    return SEED_EXERCISES.filter((item: ExerciseContent) => {
      if (item.nameZh.toLowerCase().includes(keyword)) {
        return true
      }
      if (item.nameEn.toLowerCase().includes(keyword)) {
        return true
      }
      return item.aliases.some((alias: string) => alias.toLowerCase().includes(keyword))
    })
  }

  getAlternativeExercises(exerciseId: string): ExerciseContent[] {
    const exercise = this.getExerciseById(exerciseId)
    if (exercise === undefined) {
      const empty: ExerciseContent[] = []
      return empty
    }
    return SEED_EXERCISES.filter((item: ExerciseContent) => exercise.alternativeExerciseIds.includes(item.exerciseId))
  }

  getLocalContentVersion(): number {
    return 1
  }
}

export default new ContentRepository()
```

- [ ] **Step 7: Run validation**

Run:

```powershell
git diff --check
hvigorw assembleHap --mode module -p product=default
```

Expected: static diff check passes; build proceeds beyond missing repository errors.

- [ ] **Step 8: Commit**

```powershell
git add entry/src/main/ets/mock entry/src/main/ets/shared/services/ContentRepository.ets entry/src/test/TargetLoopSkeleton.test.ets
git commit -m "feat: add local seed content repository"
```

---

### Task 3: Plan Engine and Review Calculations

**Files:**
- Create: `entry/src/main/ets/mock/SeedPlanRules.ets`
- Create: `entry/src/main/ets/shared/services/PlanEngine.ets`
- Create: `entry/src/main/ets/shared/services/ReviewService.ets`
- Modify: `entry/src/test/TargetLoopSkeleton.test.ets`

- [ ] **Step 1: Extend tests for plan and review services**

Add imports:

```typescript
import PlanEngine from '../main/ets/shared/services/PlanEngine'
import ReviewService from '../main/ets/shared/services/ReviewService'
```

Append:

```typescript
  describe('PlanEngine and ReviewService', () => {
    it('generates a minimal plan from a goal', 0, () => {
      const equipmentIds: string[] = ['eq_barbell', 'eq_dumbbell']
      const restrictedMuscleIds: string[] = []
      const goal = createUserGoal('goal_plan', 'hypertrophy', 'beginner', 3, 60, equipmentIds, restrictedMuscleIds, 1000, 1000)
      const plan = PlanEngine.generatePlan(goal)
      expect(plan.days.length).assertEqual(3)
      expect(plan.days[0].exercises.length).assertLarger(0)
      expect(plan.generatedBy).assertEqual('rule_v1')
    })

    it('calculates total volume', 0, () => {
      const sets = [
        createWorkoutSet('set_a', 'ex_barbell_bench_press', 100, 5, 8, false),
        createWorkoutSet('set_b', 'ex_barbell_bench_press', 90, 8, 8, false)
      ]
      expect(ReviewService.calculateVolume(sets)).assertEqual(1220)
    })
  })
```

- [ ] **Step 2: Run test to verify service imports fail**

Run:

```powershell
hvigorw assembleHap --mode module -p product=default
```

Expected: FAIL because `PlanEngine` and `ReviewService` do not exist.

- [ ] **Step 3: Create seed plan rules**

Create `entry/src/main/ets/mock/SeedPlanRules.ets`:

```typescript
/**
 * SeedPlanRules - first-pass rule names for plan generation.
 */

export interface PlanRule {
  ruleId: string
  goalType: string
  title: string
  targetReps: string
  intensityNote: string
}

export function createPlanRule(ruleId: string, goalType: string, title: string, targetReps: string, intensityNote: string): PlanRule {
  const item: PlanRule = {
    ruleId: ruleId,
    goalType: goalType,
    title: title,
    targetReps: targetReps,
    intensityNote: intensityNote
  }
  return item
}

export const SEED_PLAN_RULES: PlanRule[] = [
  createPlanRule('rule_hypertrophy', 'hypertrophy', '增肌基础计划', '8-12', '中等重量，控制动作节奏'),
  createPlanRule('rule_strength', 'strength', '力量基础计划', '3-5', '较高重量，延长组间休息'),
  createPlanRule('rule_fat_loss', 'fat_loss', '减脂力量计划', '10-15', '保持训练密度'),
  createPlanRule('rule_posture', 'posture', '体态改善计划', '10-12', '优先稳定和控制')
]
```

- [ ] **Step 4: Create PlanEngine**

Create `entry/src/main/ets/shared/services/PlanEngine.ets`:

```typescript
/**
 * PlanEngine - rule-based local plan generation.
 */
import {
  UserGoal,
  TrainingPlan,
  PlanDay,
  PlannedExercise,
  ExerciseContent,
  createTrainingPlan,
  createPlanDay,
  createPlannedExercise
} from '../models/TrainingModels'
import ContentRepository from './ContentRepository'
import { PlanRule, SEED_PLAN_RULES } from '../../mock/SeedPlanRules'

class PlanEngine {
  generatePlan(goal: UserGoal): TrainingPlan {
    const rule = this.findRule(goal.goalType)
    const days = this.buildDays(goal, rule)
    return createTrainingPlan('plan_' + goal.goalId, goal.goalId, rule.title, 4, days, 'rule_v1', 'active')
  }

  private findRule(goalType: string): PlanRule {
    const found = SEED_PLAN_RULES.find((item: PlanRule) => item.goalType === goalType)
    if (found !== undefined) {
      return found
    }
    return SEED_PLAN_RULES[0]
  }

  private buildDays(goal: UserGoal, rule: PlanRule): PlanDay[] {
    const days: PlanDay[] = []
    const focusMuscles: string[] = ['muscle_chest', 'muscle_back', 'muscle_legs', 'muscle_shoulders', 'muscle_core']
    let index = 0
    while (index < goal.weeklyDays) {
      const muscleId = focusMuscles[index % focusMuscles.length]
      const planned = this.buildExercisesForMuscle(muscleId, goal, rule, index)
      const dayFocus: string[] = [muscleId]
      days.push(createPlanDay('day_' + String(index + 1), index + 1, '训练日 ' + String(index + 1), dayFocus, planned))
      index += 1
    }
    return days
  }

  private buildExercisesForMuscle(muscleId: string, goal: UserGoal, rule: PlanRule, dayIndex: number): PlannedExercise[] {
    const candidates = ContentRepository.getExercisesByMuscle(muscleId)
    const planned: PlannedExercise[] = []
    let count = 0
    for (let exercise of candidates) {
      if (count >= 3) {
        break
      }
      if (this.isAllowedByEquipment(exercise, goal.equipmentIds)) {
        planned.push(createPlannedExercise('planned_' + String(dayIndex + 1) + '_' + String(count + 1), exercise.exerciseId, 3, rule.targetReps, rule.intensityNote, exercise.alternativeExerciseIds))
        count += 1
      }
    }
    return planned
  }

  private isAllowedByEquipment(exercise: ExerciseContent, equipmentIds: string[]): boolean {
    if (equipmentIds.length === 0) {
      return exercise.equipmentIds.includes('eq_bodyweight')
    }
    return exercise.equipmentIds.some((item: string) => equipmentIds.includes(item))
  }
}

export default new PlanEngine()
```

- [ ] **Step 5: Create ReviewService**

Create `entry/src/main/ets/shared/services/ReviewService.ets`:

```typescript
/**
 * ReviewService - local workout calculations.
 */
import { WorkoutSet, estimateOneRepMax } from '../models/TrainingModels'

class ReviewService {
  calculateVolume(sets: WorkoutSet[]): number {
    let total = 0
    for (let set of sets) {
      if (!set.isWarmup) {
        total += set.weight * set.reps
      }
    }
    return total
  }

  calculateBestEstimatedOneRepMax(sets: WorkoutSet[]): number {
    let best = 0
    for (let set of sets) {
      const current = estimateOneRepMax(set.weight, set.reps)
      if (current > best) {
        best = current
      }
    }
    return best
  }

  calculateCompletionRate(completedExercises: number, plannedExercises: number): number {
    if (plannedExercises <= 0) {
      return 0
    }
    const raw = completedExercises / plannedExercises * 100
    return Math.round(raw)
  }
}

export default new ReviewService()
```

- [ ] **Step 6: Run validation**

Run:

```powershell
git diff --check
hvigorw assembleHap --mode module -p product=default
```

Expected: new plan and review service imports resolve.

- [ ] **Step 7: Commit**

```powershell
git add entry/src/main/ets/mock/SeedPlanRules.ets entry/src/main/ets/shared/services/PlanEngine.ets entry/src/main/ets/shared/services/ReviewService.ets entry/src/test/TargetLoopSkeleton.test.ets
git commit -m "feat: add target loop plan and review services"
```

---

### Task 4: Local Repositories and App State

**Files:**
- Create: `entry/src/main/ets/shared/services/SyncService.ets`
- Create: `entry/src/main/ets/shared/services/WorkoutRepository.ets`
- Create: `entry/src/main/ets/app/AppState.ets`
- Modify: `entry/src/test/TargetLoopSkeleton.test.ets`

- [ ] **Step 1: Extend tests for sync and workout repository**

Add imports:

```typescript
import SyncService from '../main/ets/shared/services/SyncService'
import WorkoutRepository from '../main/ets/shared/services/WorkoutRepository'
```

Append:

```typescript
  describe('Local repositories', () => {
    it('returns local content sync status', 0, () => {
      const status = SyncService.getLocalStatus()
      expect(status.localVersion).assertEqual(1)
      expect(status.status).assertEqual('local_available')
    })

    it('stores workout sessions in memory for skeleton phase', 0, () => {
      const sets = [createWorkoutSet('set_repo', 'ex_push_up', 0, 12, 7, false)]
      const session = WorkoutRepository.createSession('session_1', 'plan_goal_1', 'day_1', 1000, 1600, 600, 1, 0, 3, 'ok', sets)
      WorkoutRepository.saveSession(session)
      expect(WorkoutRepository.getSessions().length).assertLarger(0)
    })
  })
```

- [ ] **Step 2: Create SyncService**

Create `entry/src/main/ets/shared/services/SyncService.ets`:

```typescript
/**
 * SyncService - placeholder content sync state.
 */
import { ContentSyncStatus, createContentSyncStatus } from '../models/TrainingModels'
import ContentRepository from './ContentRepository'

class SyncService {
  getLocalStatus(): ContentSyncStatus {
    return createContentSyncStatus(ContentRepository.getLocalContentVersion(), 0, 0, 'local_available')
  }

  canTrainOffline(): boolean {
    return true
  }
}

export default new SyncService()
```

- [ ] **Step 3: Create WorkoutRepository**

Create `entry/src/main/ets/shared/services/WorkoutRepository.ets`:

```typescript
/**
 * WorkoutRepository - skeleton local workout repository.
 */
import { WorkoutSession, WorkoutSet, createWorkoutSession } from '../models/TrainingModels'

class WorkoutRepository {
  private sessions: WorkoutSession[] = []

  createSession(
    sessionId: string,
    planId: string,
    dayId: string,
    startedAt: number,
    endedAt: number,
    durationSeconds: number,
    totalSets: number,
    totalVolume: number,
    fatigueScore: number,
    notes: string,
    sets: WorkoutSet[]
  ): WorkoutSession {
    return createWorkoutSession(sessionId, planId, dayId, startedAt, endedAt, durationSeconds, totalSets, totalVolume, fatigueScore, notes, sets)
  }

  saveSession(session: WorkoutSession): void {
    this.sessions.push(session)
  }

  getSessions(): WorkoutSession[] {
    return this.sessions
  }

  clear(): void {
    this.sessions = []
  }
}

export default new WorkoutRepository()
```

- [ ] **Step 4: Create AppState**

Create `entry/src/main/ets/app/AppState.ets`:

```typescript
/**
 * AppState - app-level constants and startup helpers.
 */

export class FitTrackerStores {
  static readonly GOAL: string = 'fit_tracker_goal'
  static readonly CONTENT: string = 'fit_tracker_content'
  static readonly PLANS: string = 'fit_tracker_plans'
  static readonly WORKOUTS: string = 'fit_tracker_workouts'
  static readonly RECORDS: string = 'fit_tracker_records'
}

export class StartupDecision {
  static getInitialRoute(hasGoal: boolean): string {
    if (hasGoal) {
      return 'pages/HomePage'
    }
    return 'pages/GoalSetupPage'
  }
}
```

- [ ] **Step 5: Run validation**

Run:

```powershell
git diff --check
hvigorw assembleHap --mode module -p product=default
```

Expected: new services compile or any remaining failure is unrelated and recorded.

- [ ] **Step 6: Commit**

```powershell
git add entry/src/main/ets/shared/services/SyncService.ets entry/src/main/ets/shared/services/WorkoutRepository.ets entry/src/main/ets/app/AppState.ets entry/src/test/TargetLoopSkeleton.test.ets
git commit -m "feat: add local skeleton repositories"
```

---

### Task 5: Routes and Placeholder Pages

**Files:**
- Create: `entry/src/main/ets/app/AppRoutes.ets`
- Create all placeholder page files listed in File Structure.
- Modify: `entry/src/main/resources/base/profile/main_pages.json`

- [ ] **Step 1: Create route constants**

Create `entry/src/main/ets/app/AppRoutes.ets`:

```typescript
/**
 * AppRoutes - new target-loop route constants.
 */

export class AppRoutes {
  static readonly STARTUP: string = 'app/StartupPage'
  static readonly GOAL_SETUP: string = 'features/onboarding/pages/GoalSetupPage'
  static readonly HOME: string = 'pages/HomePage'
  static readonly PLAN_HOME: string = 'features/planner/pages/PlanHomePage'
  static readonly PLAN_DAY_DETAIL: string = 'features/planner/pages/PlanDayDetailPage'
  static readonly EXERCISE_HOME: string = 'features/exercise/pages/ExerciseHomePage'
  static readonly EXERCISE_LIST: string = 'features/exercise/pages/ExerciseListPage'
  static readonly EXERCISE_DETAIL: string = 'features/exercise/pages/ExerciseDetailPage'
  static readonly WORKOUT_PREVIEW: string = 'features/workout/pages/WorkoutPreviewPage'
  static readonly ACTIVE_WORKOUT: string = 'features/workout/pages/ActiveWorkoutPage'
  static readonly WORKOUT_SUMMARY: string = 'features/workout/pages/WorkoutSummaryPage'
  static readonly REVIEW_HOME: string = 'features/review/pages/ReviewHomePage'
  static readonly MUSCLE_COVERAGE: string = 'features/review/pages/MuscleCoveragePage'
  static readonly PERSONAL_RECORDS: string = 'features/review/pages/PersonalRecordsPage'
  static readonly PROFILE_HOME: string = 'features/profile/pages/ProfileHomePage'
  static readonly CONTENT_SYNC: string = 'features/profile/pages/ContentSyncPage'
}
```

- [ ] **Step 2: Create simple placeholder page template**

For each placeholder page, use this pattern with the page-specific struct name and title. Example `entry/src/main/ets/pages/HomePage.ets`:

```typescript
/**
 * HomePage - target training loop home placeholder.
 */
import { ColorTokens, FontTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Entry
@Component
export struct HomePage {
  build() {
    Column({ space: SpacingTokens.MD }) {
      Text('今日训练')
        .fontSize(FontTokens.HEADLINE_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
      Text('目标训练闭环首页占位')
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
    }
    .width('100%')
    .height('100%')
    .padding(SpacingTokens.LG)
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
```

Use relative import paths:

- Files under `features/*/pages`: `../../../common/styles/DesignTokens`
- `app/StartupPage.ets`: `../common/styles/DesignTokens`
- `pages/HomePage.ets`: `../common/styles/DesignTokens`

Required titles:

- `StartupPage`: `FitTracker`
- `GoalSetupPage`: `目标配置`
- `PlanHomePage`: `训练计划`
- `PlanDayDetailPage`: `训练日详情`
- `ExerciseHomePage`: `动作百科`
- `ExerciseListPage`: `动作列表`
- `ExerciseDetailPage`: `动作详情`
- `WorkoutPreviewPage`: `训练预览`
- `ActiveWorkoutPage`: `训练中`
- `WorkoutSummaryPage`: `训练总结`
- `ReviewHomePage`: `训练复盘`
- `MuscleCoveragePage`: `肌群覆盖`
- `PersonalRecordsPage`: `个人记录`
- `ProfileHomePage`: `我的`
- `ContentSyncPage`: `内容同步`

- [ ] **Step 3: Update main_pages route registration**

Modify `entry/src/main/resources/base/profile/main_pages.json` so it includes old and new routes:

```json
{
  "src": [
    "pages/Index",
    "pages/RegisterPage",
    "pages/LoginPage",
    "pages/PlanDetailPage",
    "pages/WorkoutRecorderPage",
    "pages/ExerciseDetailPage",
    "pages/StatsPage",
    "pages/ExerciseLibraryPage",
    "pages/ProfilePage",
    "app/StartupPage",
    "pages/HomePage",
    "features/onboarding/pages/GoalSetupPage",
    "features/planner/pages/PlanHomePage",
    "features/planner/pages/PlanDayDetailPage",
    "features/exercise/pages/ExerciseHomePage",
    "features/exercise/pages/ExerciseListPage",
    "features/exercise/pages/ExerciseDetailPage",
    "features/workout/pages/WorkoutPreviewPage",
    "features/workout/pages/ActiveWorkoutPage",
    "features/workout/pages/WorkoutSummaryPage",
    "features/review/pages/ReviewHomePage",
    "features/review/pages/MuscleCoveragePage",
    "features/review/pages/PersonalRecordsPage",
    "features/profile/pages/ProfileHomePage",
    "features/profile/pages/ContentSyncPage"
  ]
}
```

- [ ] **Step 4: Run validation**

Run:

```powershell
git diff --check
hvigorw assembleHap --mode module -p product=default
```

Expected: route files are found by the build.

- [ ] **Step 5: Commit**

```powershell
git add entry/src/main/ets/app/AppRoutes.ets entry/src/main/ets/app/StartupPage.ets entry/src/main/ets/pages/HomePage.ets entry/src/main/ets/features entry/src/main/resources/base/profile/main_pages.json
git commit -m "feat: add target loop placeholder routes"
```

---

### Task 6: Final Static Review and Documentation Update

**Files:**
- Modify: `docs/项目重新初始化方案.md`

- [ ] **Step 1: Update initialization progress section**

Append to `docs/项目重新初始化方案.md`:

```markdown

## 10. 第一阶段实施记录

- 已创建目标训练闭环 feature-first 骨架。
- 已添加共享模型、seed 内容、内容仓库、计划规则、复盘计算和同步占位服务。
- 已添加五个核心 Tab 对应的占位页面和目标问卷入口。
- 已注册新路由，旧路由暂时保留。
- 下一阶段应把启动路由切到新 StartupPage，并逐步迁移训练记录主流程。
```

- [ ] **Step 2: Run final checks**

Run:

```powershell
git diff --check
git status --short
hvigorw assembleHap --mode module -p product=default
```

Expected:

- `git diff --check` exits 0.
- `git status --short` shows only intended files.
- Build succeeds or the first failure is documented with file and line.

- [ ] **Step 3: Commit**

```powershell
git add docs/项目重新初始化方案.md
git commit -m "docs: record clean skeleton initialization"
```

## Self-Review

Spec coverage:

- Goal configuration is covered by `UserGoal`, `GoalSetupPage`, and `PlanEngine.generatePlan()`.
- Local-first content is covered by seed files and `ContentRepository`.
- Plan generation is covered by `PlanEngine` and `SeedPlanRules`.
- Workout execution skeleton is covered by workout placeholder pages and `WorkoutRepository`.
- Review calculations are covered by `ReviewService`.
- Content sync placeholder is covered by `SyncService` and `ContentSyncPage`.
- New project initialization is covered by new feature-first folders and route registration.

Placeholder scan:

- The plan intentionally uses placeholder pages for skeleton initialization, but every placeholder page has exact names, routes, and validation criteria.
- No unresolved placeholder markers are present.

Type consistency:

- `UserGoal`, `TrainingPlan`, `PlanDay`, `PlannedExercise`, `WorkoutSet`, and `WorkoutSession` are defined in Task 1 and reused consistently.
- Service method names used in tests match the implementations in later tasks.
