# FitTracker sms-hook 服务（GoTrue Send SMS Hook 接收端 → 阿里云短信）
#
# 构建（在 deploy/sms-hook/ 目录内）：
#   docker build -t fittracker-sms-hook:local .
# 运行（示例；环境变量来自 /opt/fittracker/sms-hook.env）：
#   docker run -d --name fittracker-sms-hook --restart unless-stopped \
#     --env-file /opt/fittracker/sms-hook.env \
#     -p 127.0.0.1:8787:8787 fittracker-sms-hook:local
# 验证：curl -i -X POST http://127.0.0.1:8787/sms-hook -d '{}' → 401（无签名，符合预期）

# 注：deno 官方镜像无「:2」滚动 tag（实测 docker pull denoland/deno:2 → not found）——固定具体版本
FROM denoland/deno:2.9.6

WORKDIR /app
COPY aliyun.ts index.ts ./

# 运行期不需要 --allow-write；net 用于阿里云 HTTPS 出站与本地监听，env 用于读取注入的密钥
EXPOSE 8787
CMD ["deno", "run", "--allow-net", "--allow-env", "index.ts"]
