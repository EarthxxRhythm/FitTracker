-- FitTracker · 内容库（动作库）迁移
--
-- 执行方式（与 20261004000000_snapshots.sql 一致）：
--   ① Supabase Dashboard → SQL Editor → 粘贴本文件全文 → Run
--   ② supabase link --project-ref <YOUR_PROJECT_REF> && supabase db push
--   ③ 自托管栈：sg docker -c "docker exec -i supabase-db psql -U postgres -d postgres" < 本文件
--      （完整步骤见 server/deploy/README.md「内容库部署」小节）
--
-- 定位：产品内置动作库内容（动作 / 肌群 / 器械）落库，未登录也要能浏览。
--
-- 表结构口径：与 apps/harmony/tools/content/export-db-seed.mjs 的 EXERCISE_COLUMNS /
--   MUSCLE_COLUMNS / EQUIPMENT_COLUMNS 以及 SCHEMA_STATEMENTS **逐列、逐序、逐类型一致**，
--   也与设备端真源 apps/harmony/entry/src/main/ets/shared/services/ContentDatabaseService.ets
--   的三张宽表对齐（多值字段内嵌为 *_json 文本列，不再使用窄关联表）。
--   改动其中任何一处的列集，必须同步本文件——否则 seed 的 INSERT 会因列不匹配整单回滚。
--
-- 写入口径：客户端只读。内容更新走部署流程（export-db-seed.mjs 生成 seed → 服务器上重灌），
--   因此本文件只建 select 策略，不建 insert / update / delete / all 策略。
--
-- 幂等性：全部使用 create table if not exists / drop policy if exists，
--   重复执行或分次手工执行都不会中断（对齐 20261004000000_snapshots.sql 的风格）。
--
-- 与 seed 的执行关系：本迁移必须**先于** seed 执行。seed 头部自带同一套
--   `CREATE TABLE IF NOT EXISTS`（无 schema 前缀、无 RLS），表已存在时自动跳过；
--   随后的 INSERT 由表 owner（postgres）执行，owner 默认不受 RLS 约束，灌数据不会被策略拦截。
--
-- 本迁移不含 function / trigger，因此不涉及 security definer 与 search_path 问题，
--   也不触碰 public.snapshots（快照表的三条 RLS 策略保持零改动）。

-- ── 宽表 1 · exercises（动作，全字段宽表，含 content_version） ─────────────
create table if not exists public.exercises (
  exercise_id                text primary key,
  name_zh                    text not null,
  name_en                    text not null,
  aliases_json               text not null,
  primary_muscle_ids_json    text not null,
  secondary_muscle_ids_json  text not null,
  equipment_ids_json         text not null,
  difficulty                 text not null,
  goal_tags_json             text not null,
  video_url                  text not null,
  cover_url                  text not null,
  cover_source_label         text not null default '',
  video_source_label         text not null default '',
  media_license_text         text not null default '',
  steps_json                 text not null,
  cues_json                  text not null,
  common_mistakes_json       text not null,
  safety_notes_json          text not null,
  alternative_exercise_ids_json text not null,
  content_version            integer not null
);

-- ── 宽表 2 · muscles（肌群；name_en 为双端刻意保留的增量列） ───────────────
create table if not exists public.muscles (
  muscle_id text primary key,
  name_zh   text not null,
  region    text not null,
  name_en   text not null default ''
);

-- ── 宽表 3 · equipment（器械；name_en 同上） ─────────────────────────────
create table if not exists public.equipment (
  equipment_id text primary key,
  name_zh      text not null,
  category     text,
  name_en      text not null default ''
);

-- ── 行级安全：公开内容，匿名可读；客户端一律不可写 ────────────────────────
-- 动作库是产品内置公开内容，app 未登录也要能浏览 → select 策略用 using (true)。
-- 不建 insert / update / delete 策略 = 客户端（anon / authenticated）写请求被 RLS 拒绝。
-- 内容更新走部署流程（表 owner 灌 seed），不受此处策略影响。

alter table public.exercises enable row level security;
drop policy if exists "exercises_public_read" on public.exercises;
create policy "exercises_public_read"
  on public.exercises for select
  using (true);

alter table public.muscles enable row level security;
drop policy if exists "muscles_public_read" on public.muscles;
create policy "muscles_public_read"
  on public.muscles for select
  using (true);

alter table public.equipment enable row level security;
drop policy if exists "equipment_public_read" on public.equipment;
create policy "equipment_public_read"
  on public.equipment for select
  using (true);
