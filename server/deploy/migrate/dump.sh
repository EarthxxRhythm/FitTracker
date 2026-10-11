#!/usr/bin/env bash
# ============================================================
# FitTracker 数据迁移 · Step 1：从旧 supabase.com 项目导出
#   roles / schema / data 三段式（官方《Restore a Platform Project to Self-Hosted》流程）
#
# 运行位置：能访问旧库网络的机器（本机 / 服务器均可）
# 依赖：Node.js（npx 拉起 supabase CLI）；部分 CLI 版本经由本机 Docker 执行 dump——
#       若报「无法连接 Docker」，先在运行机上装/起 Docker 或按 CLI 提示配置。
# 用法：
#   OLD_DB_URL="postgres://postgres:<旧密码>@db.<ref>.supabase.co:5432/postgres" ./dump.sh
#   （旧密码 / 连接串：旧项目 Dashboard → Connect，选 Direct connection 或 Session pooler）
# 产出：${OUT_DIR:-./out}/{roles.sql,schema.sql,data.sql}
#
# ⚠ 产出文件含用户数据：仅存放于可信位置，迁移验证后删除或加密留存。
# ⚠ 首次执行前先跑 `npx supabase db dump --help` 核对参数名（CLI 版本间可能有差异）。
# ============================================================
set -euo pipefail

: "${OLD_DB_URL:?请设置 OLD_DB_URL（旧项目 Dashboard → Connect 的连接串）}"

OUT_DIR="${OUT_DIR:-./out}"
mkdir -p "$OUT_DIR"

echo "==> 1/3 roles（--role-only）"
npx --yes supabase@latest db dump --db-url "$OLD_DB_URL" -f "$OUT_DIR/roles.sql" --role-only

echo "==> 2/3 schema（限 auth,public）"
npx --yes supabase@latest db dump --db-url "$OLD_DB_URL" -f "$OUT_DIR/schema.sql" --schema auth,public

echo "==> 3/3 data（限 auth,public；--use-copy 走 COPY 通道）"
npx --yes supabase@latest db dump --db-url "$OLD_DB_URL" -f "$OUT_DIR/data.sql" --schema auth,public --data-only --use-copy

echo ""
echo "完成。产出："
ls -lh "$OUT_DIR"
echo ""
echo "下一步：把这三个文件送到服务器，运行 restore.sh。"
echo "提示：可先探查 schema.sql 的对象创建语句（restore.sh 头注有说明）："
echo "  grep -n -i 'create schema\|create role' \"$OUT_DIR/schema.sql\" | head"
echo "⚠ roles.sql / schema.sql / data.sql 含用户数据，妥善保管。"
