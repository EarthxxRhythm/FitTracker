-- ============================================================
-- FitTracker 数据迁移 · 对账查询
-- 用法：旧库与新库各执行一次，逐项对照——数字必须一致才继续切流。
--   psql "<库连接串>" -f verify.sql
-- ============================================================

-- ① 行数对账（最关键）
select 'users' as t, count(*) as n from auth.users
union all select 'identities', count(*) from auth.identities
union all select 'snapshots', count(*) from public.snapshots
order by t;

-- ② 用户抽样（两边各跑一次，人工逐字段对照 id/email/phone/created_at）
select id, email, phone, created_at
from auth.users
order by random()
limit 3;

-- ③ 快照抽查（两边各跑一次，user_id 与 payload 字节数对照）
select user_id, pg_column_size(payload) as payload_bytes
from public.snapshots
order by random()
limit 5;

-- ④ 迁移完整性哨兵：auth.users 中存在「identity 缺失」的用户（应为 0 行）
select u.id, u.email
from auth.users u
left join auth.identities i on i.user_id = u.id
where i.id is null
limit 10;
