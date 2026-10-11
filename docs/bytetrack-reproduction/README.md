# ByteTrack 官方 Demo 复现说明

本文档说明如何在 **Windows** 上，基于 **nwueyes 仓库内的 Git 子模块** 获取官方 [ByteTrack](https://github.com/ifzhang/ByteTrack) 源码，配置独立虚拟环境与模型权重后，运行官方视频 Demo。**暂不接入考勤业务**（`nwueyes-ruoyi`）。

**关联仓库（本组织 GitHub，非 ByteTrack 上游）：**

| 仓库 | 地址 |
|------|------|
| nwueyes（本文档 + 子模块） | `https://github.com/zzzippppp/nwueyes.git` |
| nwueyes-ruoyi | `https://github.com/zzzippppp/nwueyes-ruoyi.git` |
| nwueyes-vue3 | `https://github.com/zzzippppp/nwueyes-vue3.git` |

---

## 复现范围（务必区分）

| 类别 | 状态 | 说明 |
|------|------|------|
| **① 官方 Demo 运行验证** | **已完成（本机 + cleanroom 已验证）** | 使用官方 `tools/demo_track.py`，输入 `videos/palace.mp4`，可加载权重并生成可解码跟踪视频与非空轨迹 TXT。cleanroom 见下文 **方案 B**（2026-10-11，`pip check` 无冲突）。 |
| **② MOT17 / MOT20 等论文指标（MOTA、IDF1 等）** | **尚未完成** | 未在完整 MOT 数据集上按论文流程训练/评测；**Demo 成功不等于论文指标复现**。 |
| **③ 考勤业务是否调用本独立实现** | **尚未验证** | 业务侧可能通过 Ultralytics 等路径使用跟踪配置；**与子模块内 ByteTrack 源码无已确认的 import/部署耦合**。 |

---

## 源码交付：Git Submodule

| 项 | 内容 |
|----|------|
| 子模块路径（在 `nwueyes` 仓库内） | `external/ByteTrack` |
| 上游 URL | `https://github.com/ifzhang/ByteTrack.git` |
| 固定提交 | `d1bf0191adff59bc8fcfeaa0b33d3d1642552a99`（简称 `d1bf019`） |
| 许可证 | **MIT**（Copyright (c) 2021 Yifu Zhang）；保留原 `LICENSE` 与版权声明 |
| 禁止操作 | 勿向 **ifzhang/ByteTrack** 推送本组织修改或大文件 |

**不进 Git 的内容（须本地准备）：**

- 虚拟环境：`external/bytetrack-py310/`（或团队约定路径，见下文）
- 模型权重：`external/ByteTrack/pretrained/bytetrack_x_mot17.pth.tar`（约 **792,835,731 字节**）
- Demo 输出：`external/ByteTrack/YOLOX_outputs/` 下的视频与轨迹 TXT

父仓库 `.gitignore` 已对上述路径做额外防护；子模块上游 `.gitignore` 亦忽略 `pretrained/`、`YOLOX_outputs/` 等。

### 目录结构（`nwueyes` 仓库根目录）

```text
nwueyes\
  docs\bytetrack-reproduction\README.md
  external\
    ByteTrack\              # Git 子模块 → 官方仓库 @ d1bf019
    bytetrack-py310\        # 本地 venv（勿提交）
```

> **说明：** 若本机另有与 `nwueyes` **并列** 的历史 clone（例如父目录下的 `external\ByteTrack`），与子模块 **不是同一路径**；交付与 CI 以 **`nwueyes\external\ByteTrack` 子模块** 为准。

### 克隆与初始化子模块

**方式 A — 递归克隆（推荐）：**

```powershell
git clone --recurse-submodules https://github.com/zzzippppp/nwueyes.git
cd nwueyes
```

**方式 B — 已克隆父仓库后补拉子模块：**

```powershell
cd nwueyes
git submodule update --init --recursive
```

**核对子模块版本：**

```powershell
cd external\ByteTrack
git rev-parse HEAD
```

应输出 `d1bf0191adff59bc8fcfeaa0b33d3d1642552a99`（与父仓库 gitlink 一致）。若不一致，在子模块目录执行：

```powershell
git checkout d1bf0191adff59bc8fcfeaa0b33d3d1642552a99
```

（正常流程下 **不应** 需要；以父仓库记录的 gitlink 为准。）

---

## 依赖安装：方案 B（推荐，仅 Demo）与方案 A（官方全量）

官方 README（提交 `d1bf019`）：<https://github.com/ifzhang/ByteTrack/blob/d1bf019/README.md#installation>

| 方案 | 适用 | 说明 |
|------|------|------|
| **B（推荐）** | 只跑 `demo_track.py` 视频/图像 Demo | 不装完整 `requirements.txt`（含 ONNX/训练等）；依赖更少；**已在独立 cleanroom clone 上端到端验证**（2026-10-11）。 |
| **A** | 训练、评测、ONNX 导出等 | 与上游 Step 1～3 一致；Windows + Py3.10 下 **全量 `requirements.txt` 是否可装齐，本组织未验证**。 |

**为何方案 B 仍要装 pycocotools：** 加载 Demo 所用 exp（如 `yolox_x_mix_det.py`）时会 `import yolox.data`，进而导入 `pycocotools`，与是否训练无关。

**NumPy 1.23.5：** YOLOX/ByteTrack 跟踪代码仍使用 `np.float` 等，须 **NumPy 1.x（低于 2.0）**；本组织固定 **1.23.5**。安装 OpenCV 时请避免被解析到 **opencv-python 5.x**（要求 NumPy ≥ 2）；方案 B 实测为 **opencv-python 4.11.x**。

### 方案 B 已验证版本（cleanroom，`pip check` 通过）

| 组件 | 版本 |
|------|------|
| Python | 3.10.20 |
| torch / torchvision | 2.6.0+cu124 / 0.21.0+cu124 |
| numpy | 1.23.5 |
| opencv-python | 4.11.0.86 |
| pycocotools | 2.0.11（PyPI wheel，**非** git cocoapi 源码） |
| 其它 Demo 包 | loguru, tabulate, thop, lap, cython, scipy, cython_bbox |
| yolox | 0.1.0（`python setup.py develop`） |
| GPU | NVIDIA RTX 4060，`torch.cuda.is_available()` 为 True |

### 方案 A — 官方 Step 1～3（子模块根目录）

```shell
pip3 install -r requirements.txt
python3 setup.py develop
pip3 install cython
pip3 install 'git+https://github.com/cocodataset/cocoapi.git#subdirectory=PythonAPI'
pip3 install cython_bbox
```

若走方案 A 且 NumPy 被拉高，Demo 前可再执行 `pip install numpy==1.23.5`；全量环境可能出现 **`pip check` 与 NumPy 1.23.5 冲突**（例如 opencv-python 5.x、scikit-image），见下文历史记录。

### 历史：`pip check` 告警（早期全量/混合 venv，非方案 B）

```text
opencv-python 5.0.0.93 has requirement numpy>=2; python_version >= "3.9", but you have numpy 1.23.5.
scikit-image 0.25.2 has requirement numpy>=1.24, but you have numpy 1.23.5.
```

方案 B **不安装** scikit-image，且 OpenCV 4.11.x 与 NumPy 1.23.5 兼容；cleanroom 下 **`pip check` 无 broken requirements**。

---

## Windows PowerShell：虚拟环境与安装顺序

假定当前目录为 **`nwueyes` 仓库根目录**。

### 1. 创建并激活 venv

```powershell
py -3.10 -m venv external\bytetrack-py310
.\external\bytetrack-py310\Scripts\Activate.ps1
python --version
```

执行策略限制时可用 `external\bytetrack-py310\Scripts\activate.bat`。

### 2. 安装 PyTorch（CUDA 12.4；官方仅要求 `torch>=1.7`）

仅使用 `--index-url` 指向 PyTorch 索引时，**torchvision 等依赖可能解析失败**；请使用 **`--extra-index-url`**，并保留 PyPI 为默认源：

```powershell
pip install torch==2.6.0 torchvision==0.21.0 --extra-index-url https://download.pytorch.org/whl/cu124
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
```

### 3. 方案 B — Demo 最小依赖（推荐）

```powershell
pip install numpy==1.23.5
pip install loguru tabulate thop lap cython scipy ninja cython_bbox pycocotools
pip install "opencv-python>=4.8,<5"
Set-Location external\ByteTrack
$env:PYTHONUTF8 = "1"
python setup.py develop
Set-Location ..\..
pip check
```

**Windows 说明：**

| 问题 | 处理 |
|------|------|
| **pycocotools** | 优先 **`pip install pycocotools`**（PyPI 预编译 wheel）。官方 **`git+.../cocoapi`** 在 MSVC 下可能因 `-Wno-cpp` 等标志失败（`cl: error D8021`）。 |
| **`setup.py develop` 读 README 报错** | 子模块根目录执行前设置 **`$env:PYTHONUTF8 = "1"`**（避免 GBK 解码 `README.md` 失败）。 |
| **`yolox._C` 编译** | 需本机 **Visual Studio C++** 工具链；`cl.exe` 可能不在 PATH，但 PyTorch 扩展构建仍可能找到已安装的 VS。未装 VS 时 develop 会失败。 |
| **pip SSL 中断** | 可重试；torchvision 务必用上一节的 **`--extra-index-url`**。 |

### 4. 方案 A — 官方全量（可选）

```powershell
pip install numpy==1.23.5
Set-Location external\ByteTrack
pip install -r requirements.txt
pip install cython
pip install pycocotools
pip install cython_bbox
$env:PYTHONUTF8 = "1"
python setup.py develop
pip install numpy==1.23.5
Set-Location ..\..
pip check
```

（Windows 上 pycocotools 建议用 PyPI wheel，替代 git cocoapi。）

---

## 模型权重（Model Zoo）

| 项 | 内容 |
|----|------|
| 文件 | `external/ByteTrack/pretrained/bytetrack_x_mot17.pth.tar` |
| 本机大小（已测） | **792,835,731 字节** |
| 获取 | 官方 Model Zoo：<https://github.com/ifzhang/ByteTrack/blob/d1bf019/README.md#model-zoo> |
| Google Drive（官方 README） | <https://drive.google.com/file/d/1P4mY0Yyd3PPTybgZkjMYhFri88nTmJX5/view?usp=sharing> |

权重 **勿提交** 至 `nwueyes` 或上游 ByteTrack。

---

## Demo 命令

工作目录：**`external\ByteTrack` 子模块根目录**，venv 已激活，权重已就位：

```powershell
Set-Location external\ByteTrack
$env:PYTHONUTF8 = "1"
python tools/demo_track.py video -f exps/example/mot/yolox_x_mix_det.py -c pretrained/bytetrack_x_mot17.pth.tar --fp16 --fuse --save_result
```

默认输入：`videos/palace.mp4`。输出写入 `YOLOX_outputs/`（勿提交）。cleanroom 一次运行约 **~17 fps**（RTX 4060，fp16 + fuse）。

---

## 已验证 Demo 输出（摘要）

| 项 | 历史本机样例 | cleanroom（方案 B，2026-10-11） |
|----|--------------|----------------------------------|
| 输入 | `videos/palace.mp4` | 同左 |
| 输入帧数 | 329 | 329（官方样例视频） |
| 轨迹 TXT | 非空（样例 7,248 行 / 53 Track ID） | 非空（`YOLOX_outputs\...\*.txt`） |
| 输出视频 | 可解码 mp4 | 可解码 mp4 |

供对照，**非** MOT 评测指标。

---

## 同事复现步骤（概要）

1. `git clone --recurse-submodules` 或 `git submodule update --init --recursive`（见上文）。
2. 配置 `external\bytetrack-py310`，按 **方案 B** 安装依赖（见上文）。
3. 下载权重至 `external\ByteTrack\pretrained\`。
4. 运行 Demo 命令（建议 `$env:PYTHONUTF8 = "1"`）。
5. 执行 `pip check` 与 **验收清单**。

---

## 验收清单

### A. 建议每位同事本地检查

| # | 检查项 | 通过标准 |
|---|--------|----------|
| A1 | 子模块提交 | 在 `external\ByteTrack` 内 `git rev-parse HEAD` = `d1bf0191adff59bc8fcfeaa0b33d3d1642552a99` |
| A2 | Python | 3.10.x |
| A3 | GPU | `torch.cuda.is_available()` 为 True（CPU-only **尚未验证**） |
| A4 | 权重 | `pretrained\bytetrack_x_mot17.pth.tar` 存在 |
| A5 | 勿误提交 | 不提交 venv、权重、`YOLOX_outputs/` |

### B. 本组织已验证（非强制版本完全一致）

- **方案 B** cleanroom：`pip check` 无冲突；Demo 可跑通；输出 mp4 可解码；轨迹 TXT 非空。
- 历史全量 venv 样例：轨迹 TXT 约 7,248 行 / 53 Track ID（供数量级对照）。

### C. 不在范围

论文 MOTA/IDF1；考勤业务集成。

---

## 与考勤项目的关系

独立 Demo 模块；**尚未验证** 考勤系统是否采用同一 ByteTrack 实现。

---

## 文档维护

| 字段 | 值 |
|------|-----|
| 路径 | `docs/bytetrack-reproduction/README.md` |
| 源码 | Git 子模块 `external/ByteTrack` @ `d1bf0191adff59bc8fcfeaa0b33d3d1642552a99` |
| 最近更新 | 2026-10-11：方案 B 最小依赖、Windows/pycocotools/PyTorch 索引、cleanroom 验收 |
