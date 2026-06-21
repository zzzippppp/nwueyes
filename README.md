# nwueyes — 门口人员识别与考勤

基于 **若依 RuoYi-Vue3 + Spring Boot + PostgreSQL(pgvector) + Python(YOLO/InsightFace)** 的单门识别 MVP：萤石拉流 / 局域网 RTSP → 过线检测 → 抓拍入库 → 行为日志与考勤会话。

---

## 仓库结构（三个独立 Git 仓库）

clone 后放在**同一父目录**下：

```text
your-workspace/
├── nwueyes/          # 本仓库：总览文档（可选 clone）
├── ruoyi/            # 后端 → github.com/zzzippppp/nwueyes-ruoyi
└── RuoYi-Vue3/       # 前端 → github.com/zzzippppp/nwueyes-vue3
```

| 仓库 | 推荐分支 | 说明 |
|------|----------|------|
| [nwueyes-ruoyi](https://github.com/zzzippppp/nwueyes-ruoyi) | **`local-ruoyi`** | Java + Python 脚本 + SQL |
| [nwueyes-vue3](https://github.com/zzzippppp/nwueyes-vue3) | **`local-ruoyi-vue3`** | Vue3 管理端 |
| [nwueyes](https://github.com/zzzippppp/nwueyes) | `master` | 总览 README、部署笔记 |

```bash
mkdir nwueyes-workspace && cd nwueyes-workspace

git clone -b local-ruoyi https://github.com/zzzippppp/nwueyes-ruoyi.git ruoyi
git clone -b local-ruoyi-vue3 https://github.com/zzzippppp/nwueyes-vue3.git RuoYi-Vue3
git clone https://github.com/zzzippppp/nwueyes.git nwueyes   # 可选
```

> 根目录 `nwueyes/.gitignore` 会忽略 `ruoyi/`、`RuoYi-Vue3/`，避免嵌套仓库冲突；**实际开发在子目录各自的 Git 里提交**。

---

## 功能概览

| 模块 | 菜单路径 | 说明 |
|------|----------|------|
| 监控大屏 | 设备管理 → 监控大屏 | 萤石预览 + **开始识别**（YOLO 过线） |
| 考勤日志 | 考勤管理 → 考勤日志 | 每次进/出门流水与证据图 |
| 考勤信息 | 考勤管理 → 考勤信息 | 人员在场 / 日考勤统计 |
| 陌生人研判 | 考勤管理 → 陌生人研判 | 陌生人转熟人、合并档案 |
| 设备信息 | 设备管理 → 设备信息 | 摄像头名称、序列号、门线 ROI |
| 视频检测 | 设备管理 → 视频检测 | 上传 MP4 离线分析并入库 |

数据流：

```
摄像头/录像 → Python Worker(YOLO+过线) → POST /ingest/presence/event → Java 入库
                ↓ 抓拍 JPG                         ├ behavior_logs
                log_library/                       └ presence_sessions + persons
```

---

## 环境要求

| 依赖 | 版本 |
|------|------|
| JDK | 17+ |
| Maven | 3.8+ |
| Node.js | 18+ |
| PostgreSQL | 15+（需 **pgvector** 扩展） |
| Redis | 6+ |
| Python | 3.10 或 3.11 |

---

## 一、初始化数据库

### 方式 A：一键全量（推荐，空库）

```bash
createdb nwueyes
psql -U postgres -d nwueyes -f ruoyi/sql/nwueyes_full_install.sql
```

含若依基础表 + 业务表 + 默认菜单 + 默认摄像头 `id=1`。

### 方式 B：分步 migration

见 [`ruoyi/sql/migration/README.md`](ruoyi/sql/migration/README.md)。新装核心顺序：

```bash
psql -d nwueyes -f ruoyi/sql/ry_20260417.sql
psql -d nwueyes -f ruoyi/sql/migration/001_core_business.sql
psql -d nwueyes -f ruoyi/sql/behavior_log.sql
psql -d nwueyes -f ruoyi/sql/migration/003_fk_on_delete_set_null.sql
psql -d nwueyes -f ruoyi/sql/migration/004_video_clips_and_ai_analysis.sql
psql -d nwueyes -f ruoyi/sql/migration/005_attendance_extend.sql
psql -d nwueyes -f ruoyi/sql/migration/006_behavior_analysis.sql
psql -d nwueyes -f ruoyi/sql/migration/007_behavior_logs_restore_image_columns.sql
psql -d nwueyes -f ruoyi/sql/migration/008_platform_roster_user.sql
psql -d nwueyes -f ruoyi/sql/migration/008_menu_restructure.sql
psql -d nwueyes -f ruoyi/sql/migration/010_persons_cleanup_merge.sql
psql -d nwueyes -f ruoyi/sql/migration/011_drop_enter_face_embedding.sql
psql -d nwueyes -f ruoyi/sql/migration/012_show_video_test_menu.sql
```

默认管理员：**`admin` / `admin123`**（登录后请修改）。

安装后修改 **`camera` 表** `id=1` 的 `serial_no` 为你的萤石设备序列号（或在「设备信息」页编辑）。

---

## 二、Python 环境

venv **不随仓库分发**，每台机器单独创建：

```bash
cd ruoyi/scripts
python -m venv .venv

# Windows
.venv\Scripts\activate
# Linux / macOS
source .venv/bin/activate

pip install -U pip
pip install -r requirements.txt
pip install -r requirements-embedding.txt
```

### 模型权重

| 模型 | 位置 | 说明 |
|------|------|------|
| `osnet_x0_25_imagenet.pth` | `ruoyi/scripts/models/` | **已随仓库提交**，体态 ReID |
| `yolov8n.pt` | 工作目录或 ultralytics 缓存 | **未提交**，首次跑 YOLO 自动下载 |
| InsightFace `buffalo_l` | `~/.insightface/models/` | 首次 embed 自动下载 |

详见 [`ruoyi/scripts/models/README.md`](ruoyi/scripts/models/README.md)。

自检：

```bash
cd ruoyi
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt')"
python scripts/embed_features.py --kind face --image log_library/_probe_raw.jpg
```

---

## 三、后端配置

```bash
cd ruoyi/ruoyi-admin/src/main/resources
copy application-local.example.yml application-local.yml   # Windows
# cp application-local.example.yml application-local.yml  # Linux/macOS
```

**必须填写**（示例见 `application-local.example.yml`）：

| 配置项 | 说明 |
|--------|------|
| `ezviz.appKey` / `appSecret` | [萤石开放平台](https://open.ys7.com) |
| `presence.ingest.apiKey` | 与 Python ingest 请求头一致 |
| `presence.ingest.replayPythonCommand` | 指向 venv 的 `python.exe` 绝对路径 |
| `ruoyi.profile` | 若依上传目录，如 `./data/uploadPath` |
| `presence.ingest.storageRoot` | 抓拍根目录，如 `./data` |
| `replayLineY` / `replayRoi` | 门线/ROI（1920×1080 参考，运行时自动缩放） |
| `live.lanRtspUrl` | 可选，局域网 RTSP 主码流（识别推荐） |

**直播识别内存**：`presence.ingest.clip.enabled: false`（默认已关，主码流全帧缓存易 OOM）。

> `application-local.yml` 已在 `.gitignore`，**切勿提交**。

数据库连接默认 `localhost:5432/nwueyes`（`application-druid.yml`），可用环境变量覆盖：

```bash
set SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/nwueyes
set SPRING_DATASOURCE_USERNAME=postgres
set SPRING_DATASOURCE_PASSWORD=你的密码
```

---

## 四、启动顺序

```bash
# 1. Redis
redis-server

# 2. 后端
cd ruoyi
mvn clean package -DskipTests
java -jar ruoyi-admin/target/ruoyi-admin.jar
# 或 IDE 运行 ruoyi-admin/.../RuoYiApplication.java
# 默认 http://localhost:8080

# 3. 前端
cd RuoYi-Vue3
npm install
npm run dev
# 默认 http://localhost:80 ，/dev-api 代理到 8080
```

---

## 五、验证识别链路

1. 登录 → **设备管理 → 监控大屏**
2. 刷新配置，选择设备，填写验证码（加密设备）
3. 拉流选 **局域网 RTSP**（同网推荐）或公网云转发
4. 点击 **开始识别**（与预览独立；离开页面后识别仍全局运行，直到点「停止识别」）
5. 状态变为 **识别中** 后，过人触发进/出门
6. **考勤管理 → 考勤日志** 选当天日期并 **刷新**

Worker 启动会写 `storageRoot/log_library/_probe.jpg`（ROI + 过线），用于标定 `replayLineY` / `replayRoi`。

---

## 六、存储目录

`storageRoot` 下（默认 `./data` 或项目根，以 yml 为准）：

```text
uploadPath/                 # 若依上传、测试视频（根仓库含演示 MP4）
log_library/face|body/      # 行为日志证据图（按日期）
face_library/               # 人脸匹配库
body_library/               # 体态匹配库
snapshot_library/           # 整帧截屏
capture_manifest/           # 视频分析 manifest
```

**演示数据**：上述目录在 **nwueyes 根仓库** 已提交一份本地快照；日常识别产生的新文件仍在 `.gitignore` 中，请勿 push。

导入对应数据库行：

```bash
psql -U postgres -d nwueyes -f ruoyi/sql/seed_local_snapshot.sql
```

---

## 七、给 AI / 自动化助手的检查清单

1. 三个仓库是否同级 clone？分支是否为 `local-ruoyi` / `local-ruoyi-vue3`？
2. PostgreSQL 是否已装 pgvector？库名 `nwueyes`？
3. `application-local.yml` 是否存在且 `replayPythonCommand` 指向有效 Python？
4. Redis 是否运行？8080 / 80 端口是否占用？
5. 萤石 appKey 是否有效？摄像头 H.264？RTSP 是否已在 App 开启？
6. 识别失败时查：`live/status` 的 `logTail`、`[fatal]` 行；常见 OOM → 保持 `clip.enabled: false`、降低码率或使用子码流。

---

## 常见问题

**Q: 识别进程 exitCode=1 / 内存不足？**  
A: 关闭 `clip.enabled`；降低 `targetDetectFps` / `yoloImgsz`；或摄像头改用子码流/1080p。

**Q: RTSP 401 / 超时？**  
A: 填验证码；确认服务器与摄像头同网；萤石 App 开启 RTSP。

**Q: 行为日志无记录？**  
A: 须点 **开始识别** 而非仅预览；确认 Python 进程在跑且 `ingest.apiKey` 一致。

**Q: `clip` 是什么？要不要开？**  
A: 直播时按轨迹/场景切 **视频片段** 入库（`presence_video_clips`），供回放与 AI 分析；**不影响**过线检测、抓拍与考勤（主链路走 `/ingest/presence/event`）。默认 `clip.enabled: false`，避免主码流全帧环形缓冲占内存导致 exitCode=1。

**Q: 出了门仍「在场中」？**  
A: 出门需 exit 体态向量与 `enter_body_embedding` 相似度 ≥ `bodyMatchThreshold`（默认 0.50）。

---

## 延伸阅读

- 后端详情：[`ruoyi/NWUEYES_README.md`](ruoyi/NWUEYES_README.md)
- SQL migration：[`ruoyi/sql/migration/README.md`](ruoyi/sql/migration/README.md)
- 部署笔记：[`deployment-progress.md`](deployment-progress.md)、[`middleware-deployment.md`](middleware-deployment.md)

---

## License

MIT（与 RuoYi 一致）；YOLO、InsightFace 等模型遵循各自许可证。
