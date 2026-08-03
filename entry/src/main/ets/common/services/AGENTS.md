# common/services 目录约束

这里放稳定的应用级服务：认证、会话 token、用户资料、训练计划、训练会话、动作目录和训练草稿。跨 feature 的内容、复盘、备份、同步与内存仓库放在 `shared/services/`；训练页面专属编排放在 `features/workout/services/`。

## 服务清单

- `AuthService.ets`：本地认证与用户凭据持久化。
- `SessionManager.ets`：登录 token 生成、保存、校验和清理。
- `UserProfileService.ets`：用户资料持久化。
- `TrainingPlanService.ets`：预置计划、用户计划和当前计划指针。
- `WorkoutSessionService.ets`：旧训练会话存储、统计和个人纪录 API。
- `WorkoutDraftService.ets`：训练草稿的保存、读取和清理。
- `ExerciseService.ets`：稳定的动作目录读取 API。

## 约定

- 所有服务使用模块级默认 singleton；调用方禁止 `new`。
- preferences store 名称使用 `fit_tracker_` 前缀，写入后必须 `flush()`。
- 需要系统上下文的异步方法显式接收 `Context`，并在 preferences/API 失败时返回约定的安全默认值。
- 不要在这里加入页面 UI、跨 feature 的派生视图模型，或绕过 `WorkoutSessionPersistenceBridgeService` 的数据兼容逻辑。
