#!/usr/bin/env bash
# ============================================================
# FitTracker 数据迁移 · Step 2：还原到新自托管 Postgres
#
# 运行位置：服务器上（与 Supabase 栈同机；直接对 127.0.0.1:5432 操作）
# 用法：
#   NEW_DB_URL="postgres://postgres.your-tenant-id:<新密码>@127.0.0.1:5432/postgres" \
#   DUMP_DIR="/opt/fittracker/migrate/out" ./restore.sh
#   ⚠ 用户名须带租户后缀 `postgres.<POOLER_TENANT_ID>`：127.0.0.1:5432 是 Supavisor 连接池
#     （实测 .env 默认 your-tenant-id 可用；若无后缀会报 ENOIDENTIFIER）。
#     备选直连通路：docker exec -i supabase-db psql -U postgres -d postgres < file
#
# 全流程 = dump.sh 的三段还原 + verify.sql 对账。
# 前置条件：Supabase 栈至少启动过一次（auth schema 与角色已由栈初始化）。
#
# ⚠ 已知报错与处理：
#  · roles.sql：栈内置同名角色 →「already exists」属预期；其它错误须停下排查。
#  · schema.sql：若 dump 含 `CREATE SCHEMA auth` 等「已存在对象」语句，会在
#    ON_ERROR_STOP 下中止——先跑下面的 0/4 对象探测；必要时对该步改用容错模式：
#    去掉 -v ON_ERROR_STOP=1 单独重跑 schema 一步，逐条核对「已存在」错误是否均可解释。
# ============================================================
set -euo pipefail

: "${NEW_DB_URL:?请设置 NEW_DB_URL（新栈 Postgres 连接串）}"
: "${DUMP_DIR:?请设置 DUMP_DIR（dump.sh 的产出目录）}"

echo "==> 0/4 对象探测（schema.sql 中「可能已存在对象」的创建语句）"
grep -n -i 'create schema\|create role\|create extension' "$DUMP_DIR/schema.sql" | head -20 || echo "  （未发现 create schema/role/extension 语句）"

echo "==> 1/4 roles（已存在角色报错属预期）"
psql "$NEW_DB_URL" -f "$DUMP_DIR/roles.sql" || echo "  ⚠ roles.sql 有报错——请核对是否仅为「already exists」；其它错误须停下排查"

echo "==> 2/4 schema"
psql "$NEW_DB_URL" -v ON_ERROR_STOP=1 -f "$DUMP_DIR/schema.sql"

echo "==> 3/4 data"
psql "$NEW_DB_URL" -v ON_ERROR_STOP=1 -f "$DUMP_DIR/data.sql"

echo ""
echo "==> 4/4 对账（数字须与旧库执行同一查询的结果一致）"
psql "$NEW_DB_URL" -f "$(dirname "$0")/verify.sql"

echo ""
echo "还原与对账完成。数字不一致时：停止后续步骤，排查后再继续（旧库未被动过，可重来）。"
