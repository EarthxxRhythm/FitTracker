-- FitTracker · 演示媒体资产迁移（Storage bucket + 媒体元数据表）
--
-- 执行方式（同 20261004000000_snapshots.sql）：
--   ① Supabase Dashboard → SQL Editor → 粘贴本文件全文 → Run
--   ② supabase link --project-ref <YOUR_PROJECT_REF> && supabase db push
--   ③ 自托管栈：sg docker -c "docker exec -i supabase-db psql -U postgres -d postgres" < 本文件
--
-- 前置：20261101000000_content_library.sql（exercise_media.exercise_id 引用 public.exercises）。
-- 口径：三处命名统一 ${exerciseId}.gif，详见 docs/cloud/media-assets-granularity.md。
-- 幂等性：insert on conflict do nothing + create table if not exists + drop policy if exists。
-- 本迁移不含 function/trigger，不触碰 public.snapshots。

-- ── 1. Storage bucket（公开读：GIF 是产品内置公开内容，未登录也要能加载） ──────
insert into storage.buckets (id, name, public)
values ('exercise-media', 'exercise-media', true)
on conflict (id) do nothing;

-- ── 2. 媒体元数据表（口径字段与 FtLibraryModel.kt 的 `${id}.gif` 命名对齐） ───────
create table if not exists public.exercise_media (
  media_id         text primary key,
  exercise_id      text not null references public.exercises (exercise_id),
  media_type       text not null,
  uri              text not null,
  thumbnail_uri    text,
  view_angle       text,
  duration_seconds integer,
  license_type     text not null,
  source_note      text not null,
  checksum         text,
  sort_order       integer not null default 0
);

-- ── 3. 行级安全：公开读；客户端不可写（媒体更新走部署/上传管线） ─────────────────
alter table public.exercise_media enable row level security;
drop policy if exists "exercise_media_public_read" on public.exercise_media;
create policy "exercise_media_public_read"
  on public.exercise_media for select
  using (true);
