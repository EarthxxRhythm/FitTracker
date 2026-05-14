Task 1 — 数据字典对齐：代码库模式探索

- 核心类型和位置（已定位并可追踪到 PRD 对应实体）：
  - Exercise（ExerciseService.ets）
  - ExerciseRef、TrainingDay、PresetPlan、UserPlan（TrainingPlanService.ets）
  - SavedSet、SavedExercise、WorkoutSession、WeeklyStats、ExerciseRecord（WorkoutSessionService.ets）
  - AuthResult（AuthService.ets）
  - UserProfile、WeightUnit（UserProfileService.ets）

- 代码风格观察：接口/类型清晰、部分服务使用显式工厂函数以强制 ArkTS 的严格类型校验（arkts-no-untyped-obj-literals），便于后续数据字典抽取。
- 现状对齐：已有数据字典草案(.sisyphus/drafts/data-dictionary.md)作为 Task 2/6 的自动提取目标。
- 下一步计划（Task 2/6）：
  1) 逐类型提取字段、类型、必填/可选标记、描述；
  2) 补充字段来源（[code] 注释、[derived] 依据的推断等）；
  3) 将提取结果填充到 .sisyphus/drafts/data-dictionary.md 的结构化表格中；
  4) 与现有草案对齐，确保字段命名与现有实现一致。

- 证据定位（示例类型/字段来自的文件）：
  - ExerciseService.ets：Exercise（id, name, aliases, primaryMuscle, secondaryMuscle, equipment, description, instructions）
  - TrainingPlanService.ets：ExerciseRef、TrainingDay、PresetPlan、UserPlan
  - WorkoutSessionService.ets：SavedSet、SavedExercise、WorkoutSession、WeeklyStats、ExerciseRecord
  - AuthService.ets：AuthResult
  - UserProfileService.ets：UserProfile、WeightUnit

注：计划以 Task 2/6 的完整提取执行为准，本文档仅记录探索结果与后续执行路径。
