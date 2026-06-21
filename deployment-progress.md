# SafetyGuard 部署进度记录

记录时间：2026-06-05

服务器：`wgzrlkq-xt-server`（ubuntu）

## 当前进度

服务器部署已执行到 **公网云识别联调** 阶段。基础环境、中间件、后端、前端、Nginx 均已就绪；**「开始识别」尚未完全跑通**，当前卡在 OpenCV 读取萤石 FLV 流（`Packet mismatch`，120s 无首帧）。

下一步优先：

1. 在服务器安装/确认 `ffmpeg`，测试 **HLS（protocol=2）** 能否被 OpenCV 或 ffmpeg 读出首帧。
2. 外置配置 `application-local.yml` 中设置 `ezvizCloudProtocol: 2`。
3. 前端 `src/api/monitor/screen.js` 将 `timeout` 改为 `300000` 并 `npm run build:prod`。
4. HLS 仍失败时，在服务器上调整 `scripts/live_stream_worker_yolo.py` 的 FLV ffmpeg 选项（不改 Git 仓库亦可只改服务器副本）。

## 已完成事项

### 目录与中间件

- 已创建并使用服务器部署目录：`/opt/safetyguard`
- Docker Compose 已部署并运行：
  - PostgreSQL + pgvector：`safetyguard-postgres`（`127.0.0.1:5432`）
  - Redis：`safetyguard-redis`（`127.0.0.1:6379`）
- 数据库 `nwueyes` 已按顺序初始化：
  - `ry_20260417.sql`
  - `migration/001_core_business.sql`
  - `behavior_log.sql`
  - （可选）`migration/003_fk_on_delete_set_null.sql`
- Postgres 数据目录权限曾误改为 `ubuntu:ubuntu`，已改回 **`999:999`**

### 后端

- 后端 jar 已构建：`/opt/safetyguard/backend/ruoyi-admin/target/ruoyi-admin.jar`
- systemd 服务 `safetyguard-backend` 已启用并运行
- `curl http://127.0.0.1:8080/captchaImage` 返回 **HTTP 200**
- 日志目录：`/home/ruoyi/logs`

**systemd 关键配置（已落实）：**

```ini
EnvironmentFile=/opt/safetyguard/backend/.env
WorkingDirectory=/opt/safetyguard/backend
ExecStart=/usr/bin/java -jar /opt/safetyguard/backend/ruoyi-admin/target/ruoyi-admin.jar --spring.config.additional-location=file:/opt/safetyguard/backend/config/
```

### 配置策略（推荐方案，已采用）

| 文件 | 路径 | 用途 |
| --- | --- | --- |
| 外置业务配置 | `/opt/safetyguard/backend/config/application-local.yml` | 萤石 Key、门线、live 参数、Python 路径 |
| 密码/连接 | `/opt/safetyguard/backend/.env` | 仅 DB、Redis、`TOKEN_SECRET` |
| 数据 | `/opt/safetyguard/data/` | uploadPath、log_library、face/body_library |

已创建外置配置：

```bash
/opt/safetyguard/backend/config/application-local.yml
/opt/safetyguard/data/uploadPath
/opt/safetyguard/data/log_library
/opt/safetyguard/data/face_library
/opt/safetyguard/data/body_library
```

`application-local.yml` 主要取值（Linux 路径，与本机 `application-local.yml` 对齐）：

- `ruoyi.profile` → `/opt/safetyguard/data/uploadPath`
- `presence.ingest.workspaceRoot` → `/opt/safetyguard/backend`
- `presence.ingest.storageRoot` → `/opt/safetyguard/data`
- `presence.ingest.replayPythonCommand` → `/opt/safetyguard/backend/.venv/bin/python`
- `presence.ingest.replayIngestBaseUrl` → `http://127.0.0.1:8080`
- `presence.ingest.replayLineY` / `replayRoi` → 与本机一致（658 / 640,35,1250,680）
- `presence.ingest.live.cloudStreamOpenTimeoutSec` → **300**
- `presence.ingest.live.cloudOpenTimeoutSec` → **120**（建议，待最终确认）
- `presence.ingest.live.ezvizCloudQuality` → **2**（子码流）

### Python 算法环境

- venv：`/opt/safetyguard/backend/.venv`
- CPU 版 torch，自检 `YOLO OK`，`cuda: False`

### 前端与 Nginx

- 前端 dist：`/opt/safetyguard/frontend/dist`
- Nginx root：`/opt/safetyguard/frontend/dist`
- 反向代理：`/prod-api` → `127.0.0.1:8080`
- 监控大屏 **刷新配置有设备列表**（萤石 Key 有效）

### 萤石设备与网络排查结论

| 项 | 值 |
| --- | --- |
| 设备序列号 | `BH7367243` |
| 设备名称 | 智能考勤（CS-C6Wi-8D8W2DF） |
| 在线状态 | `status=1` 在线 |
| 视频加密 | `isEncrypt=0`（**未加密，验证码可留空**） |
| 摄像头局域网 IP | `192.168.3.49`（非 yml 中旧的 `.84`） |
| 服务器 ping 摄像头 | **不通**（100% 丢包） |

**结论：识别服务器与摄像头不在同一可达局域网，不能使用 RTSP，只能走公网云转发。**

萤石 API 自检（须用 **POST**，不能用 GET）：

- `/api/lapp/token/get` → 200
- `/api/lapp/device/list` → 有设备
- `/api/lapp/v2/live/address/get` → protocol=4（FLV）和 protocol=2（HLS）均可 200 并返回 URL

### 识别联调已排查问题

1. **外置 yml 未加载**：早期 systemd 缺少 `--spring.config.additional-location`，已补上。
2. **前端 axios 90s 超时**：`screen.js` 默认 `timeout: 90000`，CPU + 云首帧易超时；已在服务器建议改为 `300000` 并 rebuild。
3. **journalctl 看不到 `[live]` 日志**：Python worker 输出在 Java 内存中，不会写入 systemd journal。
4. **OpenCV 读 FLV 失败**：`isOpened=True` 但 120s 无首帧，ffmpeg 报 `Packet mismatch`；**根因待 HLS 方案验证**。

## 后续待办

1. **确认 ffmpeg 并测试 HLS 首帧**（见 `middleware-deployment.md` 第 6.1 节脚本）。

2. **改外置 yml 使用 HLS**：

```yaml
presence:
  ingest:
    live:
      ezvizCloudProtocol: 2
      ezvizCloudQuality: 2
      cloudStreamOpenTimeoutSec: 300
      cloudOpenTimeoutSec: 120
      yoloImgsz: 960
```

3. **前端 timeout 与 Nginx 超时对齐**：

```bash
cd /opt/safetyguard/frontend
sed -i 's/timeout: 90000/timeout: 300000/' src/api/monitor/screen.js
sed -i 's/timeout: 180000/timeout: 300000/' src/api/monitor/screen.js
npm run build:prod
```

Nginx `location /prod-api` 增加：

```nginx
proxy_read_timeout 300s;
proxy_connect_timeout 300s;
proxy_send_timeout 300s;
```

4. **YOLO 预热**（每次重启后端后建议执行）：

```bash
cd /opt/safetyguard/backend
source .venv/bin/activate
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt'); print('YOLO OK')"
deactivate
```

5. **前端试识别**：拉流选 **公网云转发**，验证码留空，点一次「开始识别」等 3～5 分钟。

6. **安全收尾**：修改 admin 默认密码、`TOKEN_SECRET`、ingest `apiKey`；生产关闭 Swagger。

7. **（可选）更新 yml 中 lanRtspUrl**：摄像头 IP 已变为 `192.168.3.49`；若未来 VPN 进局域网再用 RTSP。

## 注意事项

- **识别配置主文件是 `config/application-local.yml`**，不是 `.env` 里散落的 `PRESENCE_WORKSPACE_ROOT` 等（与 `application.yml` 占位符不一致的旧变量名勿用）。
- **jar 不包含 `application-local.yml`**（gitignore），服务器必须外置并通过 systemd `additional-location` 加载。
- 萤石取流 API `/api/lapp/v2/live/address/get` 必须用 **POST** + `application/x-www-form-urlencoded`。
- 不要用全局 `sed` 替换 dist 中 `90000`（会误改 WebRTC SDP 里的 `VP8/90000`）；应改源码 `screen.js` 后 rebuild。
- Python worker 日志不在 `journalctl`，超时排查需手动跑 OpenCV/ffmpeg 测试脚本或看 Java 返回的 `msg`。
- 生产环境不要把 PostgreSQL/Redis 暴露到公网；当前绑定 `127.0.0.1` 是正确做法。

## 关键路径速查

| 用途 | 路径 |
| --- | --- |
| 后端 jar | `/opt/safetyguard/backend/ruoyi-admin/target/ruoyi-admin.jar` |
| 外置配置 | `/opt/safetyguard/backend/config/application-local.yml` |
| 环境变量 | `/opt/safetyguard/backend/.env` |
| Python venv | `/opt/safetyguard/backend/.venv/bin/python` |
| 数据目录 | `/opt/safetyguard/data/` |
| Docker Compose | `/opt/safetyguard/compose/docker-compose.yml` |
| Nginx 站点 | `/etc/nginx/conf.d/safetyguard.conf` |
| systemd | `/etc/systemd/system/safetyguard-backend.service` |
