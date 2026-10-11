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
| **① 官方 Demo 运行验证** | **已完成（本机已验证）** | 使用官方 `tools/demo_track.py`，输入 `videos/palace.mp4`，可加载权重并生成可解码跟踪视频与非空轨迹 TXT。 |
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

## 依赖安装：官方要求 vs 本机 Demo

### 官方 README（提交 `d1bf019`，Installing on the host machine）

<https://github.com/ifzhang/ByteTrack/blob/d1bf019/README.md#installation>

**Step 1 — Install ByteTrack**（在 **`external\ByteTrack` 子模块根目录**）：

```shell
pip3 install -r requirements.txt
python3 setup.py develop
```

**Step 2 — pycocotools**：

```shell
pip3 install cython; pip3 install 'git+https://github.com/cocodataset/cocoapi.git#subdirectory=PythonAPI'
```

**Step 3 — Others**：

```shell
pip3 install cython_bbox
```

官方 **未指定** Python 小版本、PyTorch 渠道与 NumPy pin。`requirements.txt` 末尾 ONNX 相关 pin **是否在 Windows + Python 3.10 下可全部安装，本机未验证**。

### 本机 Demo 结束时实际存在的版本（已跑通 Demo）

| 组件 | 本机已测版本 |
|------|--------------|
| Python | 3.10.20 |
| PyTorch | 2.6.0+cu124 |
| torchvision | 0.21.0+cu124 |
| NumPy | 1.23.5 |
| GPU | NVIDIA RTX 4060 |

**不是**「从零按文档一键安装且无 `pip check` 告警」的已验证结论。NumPy 1.23.5 为本机 workaround（YOLOX 与 NumPy 2.x 不兼容时改用）。

### 已知 `pip check` 结果（本机 venv 实测）

```text
opencv-python 5.0.0.93 has requirement numpy>=2; python_version >= "3.9", but you have numpy 1.23.5.
scikit-image 0.25.2 has requirement numpy>=1.24, but you have numpy 1.23.5.
```

**Demo 运行成功 ≠ 环境无冲突。**

---

## Windows PowerShell：虚拟环境与建议安装顺序

假定当前目录为 **`nwueyes` 仓库根目录**。

### 1. 创建并激活 venv

```powershell
py -3.10 -m venv external\bytetrack-py310
.\external\bytetrack-py310\Scripts\Activate.ps1
python --version
```

执行策略限制时可用 `external\bytetrack-py310\Scripts\activate.bat`。

### 2. 安装 PyTorch（本机 Demo 已用；官方仅要求 `torch>=1.7`）

```powershell
pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu124
```

### 3. 固定 NumPy（本机 workaround）

```powershell
pip install numpy==1.23.5
```

### 4. 官方 Step 1～3（子模块根目录）

```powershell
Set-Location external\ByteTrack
pip install -r requirements.txt
pip install cython
pip install "git+https://github.com/cocodataset/cocoapi.git#subdirectory=PythonAPI"
pip install cython_bbox
python setup.py develop
pip install numpy==1.23.5
python -c "import numpy; print(numpy.__version__)"
Set-Location ..\..
```

### 5. 自检

```powershell
pip check
```

可能仍有 NumPy 相关告警；**尚未** 在全新空 venv 上完整端到端复验本文顺序。

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
python tools/demo_track.py video -f exps/example/mot/yolox_x_mix_det.py -c pretrained/bytetrack_x_mot17.pth.tar --fp16 --fuse --save_result
```

默认输入：`videos/palace.mp4`。输出写入 `YOLOX_outputs/`（勿提交）。

---

## 本机已验证的一次 Demo 输出（摘要）

| 项 | 值 |
|----|-----|
| 输入帧数 | 329 |
| 轨迹 TXT 行数 | 7,248 |
| 不同 Track ID 数量 | 53 |

供对照，**非** MOT 评测指标。

---

## 同事复现步骤（概要）

1. `git clone --recurse-submodules` 或 `git submodule update --init --recursive`（见上文）。
2. 配置 `external\bytetrack-py310` 与 Python 依赖（见上文）。
3. 下载权重至 `external\ByteTrack\pretrained\`。
4. 运行 Demo 命令。
5. 对照 **验收清单**。

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

### B. 本机已验证（非强制一致）

Demo 可跑通；输出视频可解码；轨迹 TXT 非空（样例 7,248 行 / 53 Track ID）。

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
