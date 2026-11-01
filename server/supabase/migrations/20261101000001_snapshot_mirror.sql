-- FitTracker · 快照镜像表迁移（6 张镜像表 + 重建触发器）
--
-- 执行方式（任选其一，同 20261004000000_snapshots.sql）：
--   ① Supabase Dashboard → SQL Editor → 粘贴本文件全文 → Run（推荐，零依赖）
--   ② supabase link --project-ref <YOUR_PROJECT_REF> && supabase db push（需 CLI 已登录）
--
-- 目的：把 public.snapshots.payload（整包 JSON）拆成可查询的关系镜像，供只读分析/管理端取数。
-- 真源仍是无结构 payload；镜像表是**派生数据**，随时可由 rebuild_snapshot_mirror() 全量重建。
--
-- 两条不变量（改动本文件前先读）：
--   ① **snapshots 表零改动**：本文件不改它的结构，也不改它的三条策略
--      （snapshots_select_own / snapshots_insert_own / snapshots_update_own，见
--      20261004000000_snapshots.sql）。客户端仍以 auth.uid() = user_id 经 PostgREST
--      自行 upsert snapshots——RLS 照常生效。
--   ② **镜像表的写路径只有一个**：security definer 触发器（以函数 owner 身份执行，
--      bypass 镜像表 RLS）。因此镜像表**只建 select 策略、不建 insert/update/delete 策略**
--      ——客户端直接写镜像表一律被拒，写入只能由真源变更派生。
--
-- 字段锚定（逐列对齐 Android @Serializable 模型，JSON 键名为 camelCase）：
--   snapshot_goals            ← apps/android/.../data/model/TrainingModels.kt  UserGoal
--   snapshot_plans            ← apps/android/.../data/model/PlanModels.kt      UserPlan
--                               （注意：备份包 plans 是 UserPlan，**不是** TrainingModels.kt 的
--                                TrainingPlan——两者是不同模型，勿混锚）
--   snapshot_sessions         ← TrainingModels.kt  WorkoutSession（不含 sets）
--   snapshot_sets             ← TrainingModels.kt  WorkoutSet
--   snapshot_body_records     ← BodyRecord.kt     WeightRecord
--   snapshot_body_measurements← BodyRecord.kt     BodyMeasurement（未录 = -1，同 MEASUREMENT_UNSET）

-- ---------------------------------------------------------------------------
-- 1. 镜像表（user_id 前置，随账号级联删除）
-- ---------------------------------------------------------------------------

-- 目标设置（payload.goal，单条）
create table if not exists public.snapshot_goals (
  user_id               uuid not null references auth.users (id) on delete cascade,
  goal_id               text not null,
  goal_type             text,
  level                 text,
  weekly_days           integer,
  session_minutes       integer,
  equipment_ids         jsonb not null default '[]'::jsonb,
  restricted_muscle_ids jsonb not null default '[]'::jsonb,
  created_at            bigint,
  updated_at            bigint,
  primary key (user_id, goal_id)
);

-- 用户启用的计划（payload.plans[]，UserPlan；JSON 键 id → 列 plan_id，days → days_json）
create table if not exists public.snapshot_plans (
  user_id          uuid not null references auth.users (id) on delete cascade,
  plan_id          text not null,
  name             text,
  cover_color      text,
  target_audience  text,
  weekly_frequency text,
  description      text,
  days_json        jsonb not null default '[]'::jsonb,
  enabled_at       bigint,
  primary key (user_id, plan_id)
);

-- 训练会话（payload.sessions[]，WorkoutSession 去掉内嵌 sets）
create table if not exists public.snapshot_sessions (
  user_id          uuid not null references auth.users (id) on delete cascade,
  session_id       text not null,
  plan_id          text,
  day_id           text,
  started_at       bigint,
  ended_at         bigint,
  duration_seconds integer,
  total_sets       integer,
  total_volume     double precision,
  fatigue_score    double precision,
  session_rpe      integer,
  notes            text,
  primary key (user_id, session_id)
);

-- 单组记录（payload.sessions[].sets[]，WorkoutSet）
create table if not exists public.snapshot_sets (
  user_id     uuid not null references auth.users (id) on delete cascade,
  session_id  text not null,
  set_id      text not null,
  exercise_id text,
  weight      double precision,
  reps        integer,
  rpe         double precision,
  is_warmup   boolean,
  primary key (user_id, session_id, set_id)
);

-- 体重记录（payload.bodyRecords[]，WeightRecord；旧包无此字段 → 0 行）
create table if not exists public.snapshot_body_records (
  user_id     uuid not null references auth.users (id) on delete cascade,
  date_millis bigint not null,
  kg          double precision,
  primary key (user_id, date_millis)
);

-- 身体测量（payload.bodyMeasurements[]，BodyMeasurement；未录入 = -1，同 MEASUREMENT_UNSET）
create table if not exists public.snapshot_body_measurements (
  user_id             uuid not null references auth.users (id) on delete cascade,
  date_millis         bigint not null,
  chest_cm            double precision not null default -1,
  waist_cm            double precision not null default -1,
  hip_cm              double precision not null default -1,
  arm_cm              double precision not null default -1,
  thigh_cm            double precision not null default -1,
  body_fat_percent    double precision not null default -1,
  skeletal_muscle_kg  double precision not null default -1,
  body_water_percent  double precision not null default -1,
  primary key (user_id, date_millis)
);

-- ---------------------------------------------------------------------------
-- 2. 行级安全：只读（客户端仅能 select 自己的行）
-- ---------------------------------------------------------------------------

alter table public.snapshot_goals             enable row level security;
alter table public.snapshot_plans             enable row level security;
alter table public.snapshot_sessions          enable row level security;
alter table public.snapshot_sets              enable row level security;
alter table public.snapshot_body_records      enable row level security;
alter table public.snapshot_body_measurements enable row level security;

-- 包顶层标量镜像（payload 顶层：schemaVersion / exportedAt / currentPlanId /
-- contentMeta.contentVersion）——补镜像盲区：无此表则云上无法回答「当前启用哪个
-- 计划 / 包是哪个版本」。
create table if not exists public.snapshot_meta (
  user_id         uuid not null references auth.users (id) on delete cascade,
  schema_version  integer,
  exported_at     bigint,
  current_plan_id text,
  content_version integer,
  mirrored_at     timestamptz not null default now(),
  primary key (user_id)
);

alter table public.snapshot_meta enable row level security;

drop policy if exists "snapshot_goals_select_own" on public.snapshot_goals;
create policy "snapshot_goals_select_own"
  on public.snapshot_goals for select
  using (auth.uid() = user_id);

drop policy if exists "snapshot_plans_select_own" on public.snapshot_plans;
create policy "snapshot_plans_select_own"
  on public.snapshot_plans for select
  using (auth.uid() = user_id);

drop policy if exists "snapshot_sessions_select_own" on public.snapshot_sessions;
create policy "snapshot_sessions_select_own"
  on public.snapshot_sessions for select
  using (auth.uid() = user_id);

drop policy if exists "snapshot_sets_select_own" on public.snapshot_sets;
create policy "snapshot_sets_select_own"
  on public.snapshot_sets for select
  using (auth.uid() = user_id);

drop policy if exists "snapshot_body_records_select_own" on public.snapshot_body_records;
create policy "snapshot_body_records_select_own"
  on public.snapshot_body_records for select
  using (auth.uid() = user_id);

drop policy if exists "snapshot_body_measurements_select_own" on public.snapshot_body_measurements;
create policy "snapshot_body_measurements_select_own"
  on public.snapshot_body_measurements for select
  using (auth.uid() = user_id);

drop policy if exists "snapshot_meta_select_own" on public.snapshot_meta;
create policy "snapshot_meta_select_own"
  on public.snapshot_meta for select
  using (auth.uid() = user_id);

-- 提示：不建 insert/update/delete 策略——镜像只由下面的 security definer 触发器写入。
-- 客户端经 PostgREST 对镜像表的一切写操作都会被 RLS 拒绝（fail-closed）。

-- ---------------------------------------------------------------------------
-- 3. 重建函数：幂等（先全删该用户镜像，再按 payload 全量重插）
-- ---------------------------------------------------------------------------

-- security definer：以函数 owner 身份执行，bypass 镜像表 RLS。
--   owner 属主说明：owner = 执行本迁移的角色。Supabase 下（Dashboard SQL Editor / supabase db push）
--   该角色为 postgres，本身 bypass RLS，语义成立。若在某环境以受限角色执行，需显式
--   `alter function public.rebuild_snapshot_mirror() owner to postgres;`（或改用镜像表 owner 角色），
--   否则触发器会以该受限角色身份写镜像表而被 RLS 拒绝。
-- set search_path：固定解析路径，避免已认证用户劫持未限定对象名（提权面）。
create or replace function public.rebuild_snapshot_mirror()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_payload jsonb := coalesce(new.payload, '{}'::jsonb);
  -- snapshots.payload 外层是 CloudPayloadEnvelope（schemaVersion/backupJson/nickname/avatar/weightUnit），
  -- 备份包本体在 backupJson **字符串**里——必须先解析一次再拆。旧版直接把 v_payload 当备份包
  -- 拆（sessions 等全 NULL → 镜像 0 行），此修复以 v_backup 为拆分真源。
  v_backup  jsonb := coalesce((v_payload ->> 'backupJson')::jsonb, '{}'::jsonb);
begin
  -- 全删：镜像表是派生数据，不做增量 diff（幂等重建）
  delete from public.snapshot_goals             where user_id = new.user_id;
  delete from public.snapshot_plans             where user_id = new.user_id;
  delete from public.snapshot_sessions          where user_id = new.user_id;
  delete from public.snapshot_sets              where user_id = new.user_id;
  delete from public.snapshot_body_records      where user_id = new.user_id;
  delete from public.snapshot_body_measurements where user_id = new.user_id;
  delete from public.snapshot_meta                 where user_id = new.user_id;

  -- goal：payload.goal 可能是 JSON null（未设置目标）→ jsonb_to_record 返回一行全 NULL，
  -- 由 goalId 非空守卫过滤掉。
  insert into public.snapshot_goals (
    user_id, goal_id, goal_type, level, weekly_days, session_minutes,
    equipment_ids, restricted_muscle_ids, created_at, updated_at
  )
  select
    new.user_id,
    g."goalId",
    g."goalType",
    g.level,
    g."weeklyDays",
    g."sessionMinutes",
    coalesce(g."equipmentIds", '[]'::jsonb),
    coalesce(g."restrictedMuscleIds", '[]'::jsonb),
    g."createdAt",
    g."updatedAt"
  -- goal：Kotlin 可空单值字段 → JSON null（标量）；jsonb_to_record(标量) 会报
  -- "cannot call populate_composite on a scalar"，故类型守卫：仅 object 才拆，
  -- 否则给空对象 → 全 NULL 行由 goalId 非空守卫过滤。
  from jsonb_to_record(case
    when jsonb_typeof(v_backup -> 'goal') = 'object' then v_backup -> 'goal'
    else '{}'::jsonb
  end) as g(
    "goalId"              text,
    "goalType"            text,
    level                 text,
    "weeklyDays"          integer,
    "sessionMinutes"      integer,
    "equipmentIds"        jsonb,
    "restrictedMuscleIds" jsonb,
    "createdAt"           bigint,
    "updatedAt"           bigint
  )
  where g."goalId" is not null;

  -- plans：备份包 plans 是 UserPlan（PlanModels.kt），JSON 键 id 映射列 plan_id、days 映射 days_json。
  insert into public.snapshot_plans (
    user_id, plan_id, name, cover_color, target_audience,
    weekly_frequency, description, days_json, enabled_at
  )
  select
    new.user_id,
    p.id,
    p.name,
    p."coverColor",
    p."targetAudience",
    p."weeklyFrequency",
    p.description,
    coalesce(p.days, '[]'::jsonb),
    p."enabledAt"
  from jsonb_to_recordset(coalesce(v_backup -> 'plans', '[]'::jsonb)) as p(
    id                 text,
    name               text,
    "coverColor"       text,
    "targetAudience"   text,
    "weeklyFrequency"  text,
    description        text,
    days               jsonb,
    "enabledAt"        bigint
  )
  where p.id is not null;

  -- sessions：内嵌 sets 保持 jsonb，单独拆到 snapshot_sets。
  insert into public.snapshot_sessions (
    user_id, session_id, plan_id, day_id, started_at, ended_at, duration_seconds,
    total_sets, total_volume, fatigue_score, session_rpe, notes
  )
  select
    new.user_id,
    t."sessionId",
    t."planId",
    t."dayId",
    t."startedAt",
    t."endedAt",
    t."durationSeconds",
    t."totalSets",
    t."totalVolume",
    t."fatigueScore",
    coalesce(t."sessionRpe", 0),
    t.notes
  from jsonb_to_recordset(coalesce(v_backup -> 'sessions', '[]'::jsonb)) as t(
    "sessionId"       text,
    "planId"          text,
    "dayId"           text,
    "startedAt"       bigint,
    "endedAt"         bigint,
    "durationSeconds" integer,
    "totalSets"       integer,
    "totalVolume"     double precision,
    "fatigueScore"    double precision,
    "sessionRpe"      integer,
    notes             text,
    sets              jsonb
  )
  where t."sessionId" is not null;

  -- sets：lateral 展开每个会话的 sets 数组；sets 缺键/NULL → 0 行，不报错。
  insert into public.snapshot_sets (
    user_id, session_id, set_id, exercise_id, weight, reps, rpe, is_warmup
  )
  select
    new.user_id,
    t."sessionId",
    s."setId",
    s."exerciseId",
    s.weight,
    s.reps,
    s.rpe,
    coalesce(s."isWarmup", false)
  from jsonb_to_recordset(coalesce(v_backup -> 'sessions', '[]'::jsonb)) as t(
    "sessionId" text,
    sets        jsonb
  )
  cross join lateral jsonb_to_recordset(coalesce(t.sets, '[]'::jsonb)) as s(
    "setId"      text,
    "exerciseId" text,
    weight       double precision,
    reps         integer,
    rpe          double precision,
    "isWarmup"   boolean
  )
  where t."sessionId" is not null and s."setId" is not null;

  -- bodyRecords / bodyMeasurements：旧版本备份包无这两个字段（Kotlin 侧为 null 默认），
  -- coalesce 兜底为 '[]' → 0 行，而不是让函数抛错打穿客户端 upsert。
  insert into public.snapshot_body_records (user_id, date_millis, kg)
  select
    new.user_id,
    r."dateMillis",
    r.kg
  from jsonb_to_recordset(coalesce(v_backup -> 'bodyRecords', '[]'::jsonb)) as r(
    "dateMillis" bigint,
    kg           double precision
  )
  where r."dateMillis" is not null;

  insert into public.snapshot_body_measurements (
    user_id, date_millis, chest_cm, waist_cm, hip_cm, arm_cm, thigh_cm,
    body_fat_percent, skeletal_muscle_kg, body_water_percent
  )
  select
    new.user_id,
    m."dateMillis",
    coalesce(m."chestCm", -1),
    coalesce(m."waistCm", -1),
    coalesce(m."hipCm", -1),
    coalesce(m."armCm", -1),
    coalesce(m."thighCm", -1),
    coalesce(m."bodyFatPercent", -1),
    coalesce(m."skeletalMuscleKg", -1),
    coalesce(m."bodyWaterPercent", -1)
  from jsonb_to_recordset(coalesce(v_backup -> 'bodyMeasurements', '[]'::jsonb)) as m(
    "dateMillis"        bigint,
    "chestCm"           double precision,
    "waistCm"           double precision,
    "hipCm"             double precision,
    "armCm"             double precision,
    "thighCm"           double precision,
    "bodyFatPercent"    double precision,
    "skeletalMuscleKg"  double precision,
    "bodyWaterPercent"  double precision
  )
  where m."dateMillis" is not null;

  -- snapshot_meta：payload 顶层标量。NULL 转型不报错（缺失键 → NULL 列），
  -- 旧包缺 contentMeta 时 content_version 为 NULL。
  insert into public.snapshot_meta (
    user_id, schema_version, exported_at, current_plan_id, content_version
  )
  values (
    new.user_id,
    (v_backup ->> 'schemaVersion')::integer,
    (v_backup ->> 'exportedAt')::bigint,
    v_backup ->> 'currentPlanId',
    ((v_backup -> 'contentMeta') ->> 'contentVersion')::integer
  );

  return null;  -- after 触发器返回值被忽略
end;
$$;

drop trigger if exists snapshots_rebuild_mirror on public.snapshots;
create trigger snapshots_rebuild_mirror
  after insert or update on public.snapshots
  for each row execute function public.rebuild_snapshot_mirror();

-- 最小化提权面：returns trigger 函数无法被普通 SELECT 直接调用（缺 trigger 伪参数），
-- 但显式 revoke 兜底——万一函数签名演化为可独立调用，也不给 authenticated 用户
-- 以 owner 身份清空/重建镜像表的入口。
revoke all on function public.rebuild_snapshot_mirror() from public;

-- ---------------------------------------------------------------------------
-- 4. 存量回填：让既有 snapshots 行重跑一次触发器
-- ---------------------------------------------------------------------------

-- 注意：PG 对 `set updated_at = updated_at` 仍执行行级 UPDATE 并触发 AFTER UPDATE 触发器
-- （值相同不跳过）。因此本语句要求**全部既有 payload 都能被上面的函数解析**；任何一条
-- 类型不符都会让本语句（在事务内执行时连同整个迁移）回滚。
-- 若某环境存量包形状不可预检，请单独执行本语句并在失败时定位该行
-- （`select user_id from public.snapshots` 逐条 `update ... where user_id = ...`）。
update public.snapshots set updated_at = updated_at;
