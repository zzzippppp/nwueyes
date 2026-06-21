# SafetyGuard 中间件服务器部署文档

本文档面向把 SafetyGuard 项目依赖的中间件统一部署到服务器的场景。当前仓库结构为：

- `backend`（或 `ruoyi/`）：Spring Boot / RuoYi 后端，默认端口 `8080`
- `frontend`（或 `RuoYi-Vue3/`）：Vite / Vue3 前端，生产接口前缀为 `/prod-api`
- `backend/scripts`：视频分析、过线检测、人脸/体态向量抽取 Python 脚本

当前部署进度记录见：`deployment-progress.md`。

**2026-06-05 更新说明**：生产环境推荐 **外置 `config/application-local.yml` + 最小 `.env`**，与本地开发一致；识别相关参数不要仅依赖 `.env` 中旧的 `PRESENCE_WORKSPACE_ROOT` 等变量名（与 `application.yml` 实际占位符不一致）。

---

## 1. 中间件清单

| 类型 | 是否需要单独部署 | 推荐版本 | 项目配置位置 | 说明 |
| --- | --- | --- | --- | --- |
| PostgreSQL + pgvector | 是 | PostgreSQL 15+，pgvector latest | `application-druid.yml` + `.env` | 主业务库 `nwueyes`，向量字段依赖 `pgvector` |
| Redis | 是 | Redis 7.x | `application.yml` + `.env` | 登录 token、验证码、缓存、限流等 |
| Nginx | 是 | 稳定版 | `frontend/.env.production` | 托管前端静态资源，反向代理 `/prod-api` 到后端 |
| ffmpeg | 是（识别必需） | 系统包最新稳定版 | 系统依赖 | OpenCV 读萤石 FLV/HLS 依赖 ffmpeg；未安装易超时 |
| 文件存储目录 | 是，使用服务器本地磁盘 | 按目录规划 | `application-local.yml` | `ruoyi.profile`、`storageRoot`；上传、抓拍、档案库 |
| Python 算法运行环境 | 需要部署运行时 | Python 3.10/3.11 | `scripts/requirements*.txt` | YOLO/OpenCV、InsightFace、torchreid |
| 萤石开放平台 | 外部服务 | 官方服务 | `application-local.yml` → `ezviz.*` | 设备接入、公网直播流 |
| Druid / Quartz | 否 | Java 依赖 | Maven / 数据库表 | 嵌入后端 |

未在当前代码中发现需要单独部署的 MySQL、RabbitMQ、Kafka、MinIO。

---

## 2. 全新服务器初始化

以下命令以 Linux 服务器为例（已在 `wgzrlkq-xt-server` 验证 Ubuntu）。

### 2.1 创建部署目录

```bash
sudo mkdir -p /opt/safetyguard
sudo chown -R ubuntu:ubuntu /opt/safetyguard
```

目录规划：

```text
/opt/safetyguard/
  backend/              # 后端源码、jar、scripts、.venv
  backend/config/       # 外置 application-local.yml（不提交 Git）
  frontend/             # 前端源码与 dist
  compose/              # docker-compose.yml
  data/
    uploadPath/
    log_library/
    face_library/
    body_library/
    postgres/
    redis/
  logs/
  backups/
```

### 2.2 安装基础工具

```bash
sudo apt update
sudo apt install -y ca-certificates curl git unzip rsync nginx openjdk-17-jdk maven \
  python3 python3-venv python3-pip nodejs npm ffmpeg
java -version
ffmpeg -version | head -1
```

**ffmpeg 为公网识别必需**，不可省略。

### 2.3 安装 Docker 和 Docker Compose

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
sudo docker compose version
```

### 2.4 安装 Node.js（前端构建）

```bash
npm config set registry https://registry.npmmirror.com
node -v
npm -v
```

---

## 3. 部署 PostgreSQL + pgvector 与 Redis

创建 `/opt/safetyguard/compose/docker-compose.yml`：

```yaml
services:
  postgres:
    image: pgvector/pgvector:pg15
    container_name: safetyguard-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: nwueyes
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: change-me-postgres-password
      TZ: Asia/Shanghai
    ports:
      - "127.0.0.1:5432:5432"
    volumes:
      - /opt/safetyguard/data/postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d nwueyes"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: safetyguard-redis
    restart: unless-stopped
    command: >
      redis-server
      --appendonly yes
      --requirepass change-me-redis-password
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - /opt/safetyguard/data/redis:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "change-me-redis-password", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
```

启动：

```bash
cd /opt/safetyguard/compose
sudo docker compose up -d
sudo docker compose ps
```

**Postgres 数据目录属主必须为容器用户 `999:999`**，勿改为 `ubuntu:ubuntu`。

初始化数据库（**必须逐条、按顺序执行**）：

```bash
cd /opt/safetyguard/backend
sudo docker exec -i safetyguard-postgres psql -U postgres -d nwueyes < sql/ry_20260417.sql
sudo docker exec -i safetyguard-postgres psql -U postgres -d nwueyes < sql/migration/001_core_business.sql
sudo docker exec -i safetyguard-postgres psql -U postgres -d nwueyes < sql/behavior_log.sql
sudo docker exec -i safetyguard-postgres psql -U postgres -d nwueyes < sql/migration/003_fk_on_delete_set_null.sql
```

---

## 4. 后端配置（推荐：外置 yml + 最小 .env）

### 4.1 最小 `.env`（仅密码与连接）

创建 `/opt/safetyguard/backend/.env`：

```bash
SPRING_DATASOURCE_URL=jdbc:postgresql://127.0.0.1:5432/nwueyes
SPRING_DATASOURCE_USERNAME=postgres
SPRING_DATASOURCE_PASSWORD=change-me-postgres-password

SPRING_DATA_REDIS_HOST=127.0.0.1
SPRING_DATA_REDIS_PORT=6379
SPRING_DATA_REDIS_DATABASE=0
SPRING_DATA_REDIS_PASSWORD=change-me-redis-password

TOKEN_SECRET=change-me-long-random-jwt-secret
```

**不要**在 `.env` 中混用与 `application.yml` 不一致的旧变量名（如 `PRESENCE_WORKSPACE_ROOT`）。识别、萤石、门线等统一写入外置 yml。

### 4.2 外置 `application-local.yml`

```bash
sudo mkdir -p /opt/safetyguard/backend/config
sudo mkdir -p /opt/safetyguard/data/{uploadPath,log_library,face_library,body_library}
```

创建 `/opt/safetyguard/backend/config/application-local.yml`（示例结构，密钥请替换）：

```yaml
ruoyi:
  profile: /opt/safetyguard/data/uploadPath

ezviz:
  appKey: your-ezviz-app-key
  appSecret: your-ezviz-app-secret

presence:
  ingest:
    enabled: true
    apiKey: local-presence-key
    defaultLocationId: 1
    workspaceRoot: /opt/safetyguard/backend
    replayScriptPath: scripts/video_replay_worker_yolo.py
    analyzeScriptPath: scripts/video_analyze_yolo.py
    replayProfileRoot: /opt/safetyguard/data/uploadPath
    replayIngestBaseUrl: http://127.0.0.1:8080
    replayLineY: 658
    replayRoi: 640,35,1250,680
    captureScriptPath: scripts/capture_best_snapshots.py
    storageRoot: /opt/safetyguard/data
    snapshotWindowSec: 2.5
    embedScriptPath: scripts/embed_features.py
    faceEmbedModel: buffalo_l
    bodyEmbedModel: osnet_x0_25
    faceMinDetScore: 0.45
    faceMatchThreshold: 0.45
    bodyMatchThreshold: 0.50
    liveScriptPath: scripts/live_stream_worker_yolo.py
    replayPythonCommand: /opt/safetyguard/backend/.venv/bin/python
    live:
      targetDetectFps: 15
      yoloImgsz: 960
      yoloConf: 0.20
      cloudStreamOpenTimeoutSec: 300
      cloudOpenTimeoutSec: 120
      ezvizCloudProtocol: 2
      ezvizCloudQuality: 2
      ezvizStreamExpireSec: 3600
      enterFaceHuntMaxSec: 10
      enterFaceGraceSec: 1.5
      # 仅当识别服务器与摄像头同网时可用；云服务器通常 ping 不通摄像头 IP
      lanRtspUrl: rtsp://admin:YOUR_CODE@192.168.x.x:554/h264/ch1/main/av_stream
```

权限：

```bash
sudo chmod 600 /opt/safetyguard/backend/config/application-local.yml
```

### 4.3 构建与 systemd

```bash
cd /opt/safetyguard/backend
mvn -pl ruoyi-admin -am package -DskipTests
```

`/etc/systemd/system/safetyguard-backend.service`：

```ini
[Unit]
Description=SafetyGuard Backend
After=network.target docker.service

[Service]
Type=simple
WorkingDirectory=/opt/safetyguard/backend
EnvironmentFile=/opt/safetyguard/backend/.env
ExecStart=/usr/bin/java -jar /opt/safetyguard/backend/ruoyi-admin/target/ruoyi-admin.jar --spring.config.additional-location=file:/opt/safetyguard/backend/config/
Restart=always
RestartSec=5
User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now safetyguard-backend
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8080/captchaImage
```

---

## 5. RTSP 与公网云：如何选择

| 场景 | 推荐拉流模式 |
| --- | --- |
| 识别服务器与摄像头 **同一局域网**（服务器能 ping 通摄像头 IP） | 局域网 RTSP（画质高、延迟低） |
| 识别服务器在 **云机房/异地**（ping 摄像头 192.168.x.x 不通） | **公网云转发**（`cloud_hls` / 萤石 API protocol 2 或 4） |

验证命令（在**识别服务器**上执行）：

```bash
ping -c 3 192.168.3.49
nc -zv 192.168.3.49 554
```

App 能预览不代表 RTSP 可用；App 走萤石云，RTSP 需服务器直连摄像头。

---

## 6. Python 算法运行环境

```bash
cd /opt/safetyguard/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r scripts/requirements.txt
pip install -r scripts/requirements-embedding.txt
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt'); print('YOLO OK')"
deactivate
```

CPU 服务器使用 CPU 版 torch；识别前建议预热 YOLO。

### 6.1 公网流自检（部署后必做）

萤石取流 API 必须使用 **POST**（GET 会返回 `49999 Data error`）。

一键测试 token → 设备 → FLV/HLS URL → OpenCV 首帧：

```bash
cd /opt/safetyguard/backend
source .venv/bin/activate

python3 <<'PY'
import re, time, json, urllib.parse, urllib.request, subprocess, shutil
import cv2, os

cfg = open("/opt/safetyguard/backend/config/application-local.yml", encoding="utf-8").read()
app_key = re.search(r"appKey:\s*(\S+)", cfg).group(1)
app_secret = re.search(r"appSecret:\s*(\S+)", cfg).group(1)

def post(path, data):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(
        "https://open.ys7.com" + path, data=body, method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())

def get_url(protocol):
    tok = post("/api/lapp/token/get", {"appKey": app_key, "appSecret": app_secret})
    access = tok["data"]["accessToken"]
    serial = post("/api/lapp/device/list", {"accessToken": access, "pageStart": 0, "pageSize": 50})["data"][0]["deviceSerial"]
    live = post("/api/lapp/v2/live/address/get", {
        "accessToken": access, "deviceSerial": serial, "channelNo": 1,
        "protocol": protocol, "type": 1, "expireTime": 3600, "quality": 2, "supportH265": 0,
    })
    return live["data"]["url"], serial, live.get("code"), live.get("msg")

for proto, name in [(4, "FLV"), (2, "HLS")]:
    url, serial, code, msg = get_url(proto)
    print(f"\n=== {name} api={code} {msg} ===")
    print("url:", url[:100], "...")
    os.environ["OPENCV_FFMPEG_CAPTURE_OPTIONS"] = (
        "fflags;nobuffer|max_delay;500000" if proto == 4
        else "fflags;nobuffer|probesize;5000000|analyzeduration;5000000"
    )
    cap = cv2.VideoCapture(url, cv2.CAP_FFMPEG)
    t0 = time.time()
    ok = False
    for i in range(90):
        ret, frame = cap.read()
        if ret and frame is not None and frame.size > 0:
            print(f"OpenCV OK: {frame.shape} in {time.time()-t0:.1f}s")
            ok = True
            break
        if i % 15 == 0:
            print(f"waiting... {int(time.time()-t0)}s")
        time.sleep(1)
    cap.release()
    if not ok:
        print("OpenCV FAIL")
PY

deactivate
```

**已知问题（2026-06-05）**：部分环境下 OpenCV 读萤石 **FLV** 会出现 `Packet mismatch` 且长时间无首帧；优先改用 **HLS（protocol=2）** 并在 yml 中设置 `ezvizCloudProtocol: 2`。

---

## 7. 前端与 Nginx

### 7.1 前端 timeout（识别启动必需）

`src/api/monitor/screen.js` 中 `startLiveRecognize` 默认 `timeout: 90000`，CPU + 云首帧不足。服务器构建前修改：

```javascript
timeout: 300000
```

```bash
cd /opt/safetyguard/frontend
npm install
npm run build:prod
```

勿对 `dist` 全局 `sed` 替换 `90000`（会误改 WebRTC 的 `VP8/90000`）。

### 7.2 Nginx

`/etc/nginx/conf.d/safetyguard.conf` 示例：

```nginx
server {
    listen 80;
    server_name your-domain.example.com;

    root /opt/safetyguard/frontend/dist;
    index index.html;
    client_max_body_size 30m;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /prod-api/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### 7.3 监控大屏识别操作

1. 拉流模式：**公网云转发**
2. 设备加密（`isEncrypt=1`）时填写验证码；未加密可留空
3. 点一次「开始识别」，等待 3～5 分钟
4. 行为日志需手动选日期并刷新

---

## 8. 防火墙与安全建议

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 5432/tcp
sudo ufw deny 6379/tcp
sudo ufw deny 8080/tcp
```

安全检查项：

- 修改 admin 默认密码、PostgreSQL/Redis/JWT/ingest `apiKey`
- 勿将 `application-local.yml`、`.env` 提交 Git
- PostgreSQL/Redis 仅绑定 `127.0.0.1`
- 定期备份 `/opt/safetyguard/data/postgres` 与业务数据目录

---

## 9. 常用运维命令

```bash
# 中间件
cd /opt/safetyguard/compose && sudo docker compose ps

# 后端
sudo systemctl status safetyguard-backend
sudo journalctl -u safetyguard-backend -n 100 --no-pager
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8080/captchaImage

# 配置检查
grep -E 'cloudStream|ezvizCloud|cloudOpen' /opt/safetyguard/backend/config/application-local.yml
sudo systemctl cat safetyguard-backend | grep ExecStart

# 数据库备份
sudo docker exec safetyguard-postgres pg_dump -U postgres -d nwueyes -Fc > /opt/safetyguard/backups/nwueyes_$(date +%F).dump
```

---

## 10. 发布流程建议

1. `git pull` 拉取 backend / frontend 最新代码。
2. 如有 SQL 变更，按序执行 migration。
3. **不要覆盖** `/opt/safetyguard/backend/config/application-local.yml` 和 `.env`。
4. 后端：`mvn -pl ruoyi-admin -am package -DskipTests` → `systemctl restart safetyguard-backend`。
5. 前端：确认 `screen.js` timeout → `npm run build:prod` → Nginx 自动 serving 新 dist。
6. Python 依赖变更时：`pip install -r scripts/requirements*.txt` → 重启后端。
7. 验证：登录、captchaImage、监控大屏设备列表、公网识别、行为日志。

---

## 11. 故障排查速查

| 现象 | 可能原因 | 处理 |
| --- | --- | --- |
| `timeout of 90000ms exceeded` | 前端 axios 超时 | 改 `screen.js` 为 300000 并 rebuild |
| `公网直播流仍在连接中但超过等待上限` | OpenCV 未读到首帧 | 装 ffmpeg；改 HLS protocol=2；加长 timeout |
| 萤石 API `49999` | 取流用了 GET 而非 POST | 使用 POST form 调用 |
| `journalctl` 无 `[live]` | Python 日志在 Java 内存 | 用手动 OpenCV/ffmpeg 脚本排查 |
| RTSP 失败 | 服务器不在摄像头局域网 | 改用公网云转发 |
| `Packet mismatch` + FLV 无画面 | OpenCV/ffmpeg 解 FLV 兼容 | 改用 HLS 或调整 worker ffmpeg 选项 |
