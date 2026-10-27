-- FitTracker · Supabase 初始化迁移（Wave 6）
--
-- 执行方式（任选其一）：
--   ① Supabase Dashboard → SQL Editor → 粘贴本文件全文 → Run（推荐，零依赖）
--   ② supabase link --project-ref <YOUR_PROJECT_REF> && supabase db push（需 CLI 已登录）
--
-- 说明：publishable key 为公开客户端凭据，数据访问受本文件的 RLS 约束。

-- 快照表：每用户一行整包备份（payload 与本地 UserDataBackupPackage 的 JSON 结构一致）
create table if not exists public.snapshots (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  payload    jsonb not null,
  updated_at timestamptz not null default now()
);

-- 行级安全：仅本人可读写自己的行（客户端用 anon/publishable 凭据直连的唯一安全边界）
alter table public.snapshots enable row level security;

drop policy if exists "snapshots_select_own" on public.snapshots;
create policy "snapshots_select_own"
  on public.snapshots for select
  using (auth.uid() = user_id);

drop policy if exists "snapshots_insert_own" on public.snapshots;
create policy "snapshots_insert_own"
  on public.snapshots for insert
  with check (auth.uid() = user_id);

drop policy if exists "snapshots_update_own" on public.snapshots;
create policy "snapshots_update_own"
  on public.snapshots for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 提示：不建 delete 策略——快照不提供客户端删除（清空数据请用 Dashboard）。
