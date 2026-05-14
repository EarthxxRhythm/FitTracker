### FitTracker PRD 数据字典
（基于 Task 2 输出的代码接口自动提取字段）

- 本字典覆盖以下核心类型及其字段：ExerciseRef、TrainingDay、PresetPlan、UserPlan、SavedSet、SavedExercise、WorkoutSession、WeeklyStats、ExerciseRecord、Exercise、AuthResult、UserProfile。
- 字段说明尽量贴合代码实现，如无显式必填约束则按常规默认推断。
- 来源标注：'[code]' 表示字段来自代码定义，'[derived]' 表示依据代码使用场景推断。

| 字段名 | 类型 | 必填 | 说明 | 来源文件/注释 |
|---|---|---|---|---|

## ExerciseRef
- name | string | true | 动作名称 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- targetMuscle | string | true | 目标肌群 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- sets | number | true | 建议的组数 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- reps | string | true | 每组重复次数描述（如 "8-12"） | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |

## TrainingDay
- dayLabel | string | true | 天别标签 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- exercises | ExerciseRef[] | true | 当日训练的动作清单 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- dayOfWeek | number[] | false | 指定周几训练，0=Sun, 1=Mon, ..., 6=Sat；缺省时自动分布 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |

## PresetPlan
- id | string | true | 预置计划唯一标识 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- name | string | true | 计划名称 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- coverColor | string | true | 封面颜色（用于 UI） | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- targetAudience | string | true | 目标人群 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- weeklyFrequency | string | true | 每周训练频率 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- days | TrainingDay[] | true | 训练日列表 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |

## UserPlan
- id | string | true | 用户自定义计划唯一标识 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- name | string | true | 计划名称 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- coverColor | string | true | 封面颜色 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- targetAudience | string | true | 目标人群 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- weeklyFrequency | string | true | 每周训练频率 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- days | TrainingDay[] | true | 训练日列表 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |
- enabledAt | number | true | 启用时间戳 | [code] entry/src/main/ets/common/services/TrainingPlanService.ets |

## SavedSet
- weight | number | true | 重量（单位按全局权重单位设置） | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- reps | number | true | 次数 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |

## SavedExercise
- name | string | true | 动作名称 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- targetMuscle | string | true | 目标肌群 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- sets | SavedSet[] | true | 组成该动作的所有组 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |

## WorkoutSession
- id | string | true | 会话唯一标识 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- planId | string | true | 关联计划 ID | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- planName | string | true | 计划名称 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- dayLabel | string | true | 会话对应日期标签 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- startTime | number | true | 会话开始时间（时间戳） | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- endTime | number | true | 会话结束时间 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- durationSeconds | number | true | 持续时长（秒） | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- totalSets | number | true | 总组数 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- totalVolume | number | true | 总容量（重量×组数） | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- notes | string | false | 备注 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- exercises | SavedExercise[] | true | 当日动作清单 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- createdAt | string | true | 创建时间戳 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |

## WeeklyStats
- count | number | true | 本周训练次数 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- duration | number | true | 总时长（秒） | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- sets | number | true | 总组数 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- volume | number | true | 总容量（重量×组数） | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |

## ExerciseRecord
- exerciseName | string | true | 动作名称 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- best1RM | number | true | 最高 1RM | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- bestWeight | number | true | 峰值重量 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- bestReps | number | true | 对应重复次数 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |
- bestDate | string | true | 记录日期 | [code] entry/src/main/ets/common/services/WorkoutSessionService.ets |

## Exercise
- id | string | true | 动作标识 | [code] entry/src/main/ets/common/services/ExerciseService.ets |
- name | string | true | 动作名称 | [code] entry/src/main/ets/common/services/ExerciseService.ets |
- aliases | string[] | true | 别名 | [code] entry/src/main/ets/common/services/ExerciseService.ets |
- primaryMuscle | string | true | 主肌群 | [code] entry/src/main/ets/common/services/ExerciseService.ets |
- secondaryMuscle | string | true | 次要肌群 | [code] entry/src/main/ets/common/services/ExerciseService.ets |
- equipment | string | true | 设备类型 | [code] entry/src/main/ets/common/services/ExerciseService.ets |
- description | string | true | 描述 | [code] entry/src/main/ets/common/services/ExerciseService.ets |
- instructions | string | true | 操作要点 | [code] entry/src/main/ets/common/services/ExerciseService.ets |

## AuthResult
- success | boolean | true | 是否认证成功 | [code] entry/src/main/ets/common/services/AuthService.ets |
- message | string | true | 认证消息 | [code] entry/src/main/ets/common/services/AuthService.ets |
- token | string | true | 身份令牌 | [code] entry/src/main/ets/common/services/AuthService.ets |

## UserProfile
- nickname | string | true | 昵称 | [code] entry/src/main/ets/common/services/UserProfileService.ets |
- avatar | string | true | 头像占位/链接 | [code] entry/src/main/ets/common/services/UserProfileService.ets |
- weightUnit | WeightUnit | true | 体重单位，可选 kg 或 lbs | [code] entry/src/main/ets/common/services/UserProfileService.ets |

> WeightUnit 类型：'kg' | 'lbs'（来自 UserProfileService.ets）

### 备注
- 本草案基于现有代码实现，字段名与结构可能随后迭代调整，请以实际实现为准。
