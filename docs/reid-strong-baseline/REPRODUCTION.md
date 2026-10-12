# Strong Baseline + BNNeck — 完整复现说明（Market1501 推理）

## 1. 目标与边界

**目标：** 使用官方仓库的 `tools/test.py`，在 Market1501 上加载作者提供的 **epoch-120 预训练权重**，输出 **mAP** 与 **CMC Rank-k**。

**包含：**

- 环境搭建（Python 3.10、PyTorch CUDA、依赖）
- 数据集与权重下载、校验、解压
- 与官方 shell 脚本等价的测试配置（after-BNNeck + 特征 L2 归一化，无 re-ranking）

**不包含：**

- 训练、`Experiment-*.sh` 全流程
- `Test-reranking-*.sh`、DukeMTMC-reID
- 论文全部消融与表格逐项对齐
- 视频时序融合、nwueyes 业务集成

---

## 2. 获取官方源码

```powershell
git clone https://github.com/michuanhaohao/reid-strong-baseline.git
cd reid-strong-baseline
git checkout 3da7e6f03164a92e696cb6da059b1cd771b0346d
```

记录 commit 便于团队对齐。后续命令均假设当前目录为 **`reid-strong-baseline` 仓库根**（下称 `$ReidRepoRoot`）。

---

## 3. Python 环境

### 3.1 版本要求

| 组件 | 建议 |
|------|------|
| Python | **3.10.x** |
| PyTorch | **2.6.0+cu124**（与 CUDA 12.4 驱动匹配；无 GPU 可改用 CPU 版，但官方脚本默认 `cuda`） |
| torchvision | **0.21.0+cu124** |

### 3.2 创建 venv（示例）

```powershell
py -3.10 -m venv ..\reid-strong-baseline-py310
..\reid-strong-baseline-py310\Scripts\Activate.ps1
python -m pip install -U pip
```

### 3.3 安装 PyTorch（CUDA 示例）

从 [pytorch.org](https://pytorch.org) 选择 Windows + pip + CUDA 12.4，例如：

```powershell
pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu124
```

### 3.4 其余依赖

在 venv 中安装本仓库提供的清单（路径相对于 **nwueyes** 克隆）：

```powershell
pip install -r path\to\nwueyes\docs\reid-strong-baseline\requirements-reproduction.txt
```

可选（仅下载 Google Drive 时需要）：

```powershell
pip install gdown>=6.4.2
```

### 3.5 CUDA 自检

```powershell
python -c "import torch; print(torch.__version__, 'cuda=', torch.cuda.is_available(), 'count=', torch.cuda.device_count())"
```

### 3.6 与上游 README 的差异（重要）

| 项 | 上游 README | 本复现实际 |
|----|-------------|------------|
| pytorch-ignite | 0.1.2 | **0.3.0**（0.1.2 在 torch 2.6 上会因 `torch._six` 等报错） |
| Windows DataLoader | `NUM_WORKERS: 8` | 测试时建议 **`NUM_WORKERS=0`**（CLI 覆盖，无需改源码） |

---

## 4. Market1501 数据集

### 4.1 官方来源

- 项目页（Link 1 Google Drive / Link 2 百度盘等）：[Zheng Lab — Market-1501](https://zheng-lab-anu.github.io/Project/project_reid.html)
- 上游 README 亦指向 [liangzheng.org 项目页](http://www.liangzheng.org/Project/project_reid.html)

**Google Drive 文件 ID（常用 zip）：** `0B8-rUzbwVRk0c054eEozWG9COHM`  
**文件名：** `Market-1501-v15.09.15.zip`

### 4.2 校验（强烈建议）

| 检查 | 期望值 |
|------|--------|
| 文件大小 | **152733771** 字节 |
| MD5 | `65005ab7d12ec1c44de4eeafe813e68a` |

PowerShell 示例：

```powershell
Get-FileHash .\Market-1501-v15.09.15.zip -Algorithm MD5
(Get-Item .\Market-1501-v15.09.15.zip).Length
```

ZIP 完整性（Python）：

```powershell
python -c "import zipfile; z=zipfile.ZipFile('Market-1501-v15.09.15.zip'); print('testzip', z.testzip())"
```

### 4.3 目录结构

解压到 `$ReidRepoRoot\data\market1501\`，需包含（至少）：

```text
data/market1501/
  bounding_box_train/
  query/
  bounding_box_test/
```

若 zip 内顶层为 `Market-1501-v15.09.15/`，解压后 **重命名** 为 `market1501`。  
设置 `DATASETS.ROOT_DIR` 为 **`$ReidRepoRoot/data`**（注意官方代码在 `data` 下再找 `market1501` 子目录）。

### 4.4 下载示例（gdown + 代理，可选）

需能访问 Google；代理示例（**勿将个人代理写入 Git**）：

```powershell
$env:HTTP_PROXY = "http://127.0.0.1:7897"   # 按本机修改
$env:HTTPS_PROXY = $env:HTTP_PROXY
$env:NO_PROXY = ""
python -m gdown "https://drive.google.com/uc?export=download&id=0B8-rUzbwVRk0c054eEozWG9COHM" `
  -O downloads\Market-1501-v15.09.15.zip --proxy $env:HTTP_PROXY
```

---

## 5. 预训练权重（Market1501）

### 5.1 官方来源

- README 表格链接（Google Drive **文件夹**）：  
  `https://drive.google.com/open?id=1hn0sXLZ5yJcxtmuY-ItQfYD7hBtHwt7A`

**注意：** 该 ID 是 **文件夹**，不能对文件夹 ID 使用 `uc?export=download&id=<文件夹ID>`（会 HTTP 500）。应下载文件夹内 **45 个分卷** 或整文件夹。

### 5.2 分卷命名与大小

| 文件 | 大小（字节） |
|------|----------------|
| `market_resnet50_model_120_rank1_945.zip.001` … `.044` | 各 **2097152** |
| `market_resnet50_model_120_rank1_945.zip.045` | **1514267** |
| **合计** | **93788955** |

存放建议：`$ReidRepoRoot\pretrained\market1501\`

### 5.3 下载方式

1. **浏览器：** 打开上述文件夹，下载全部 `.001`–`.045`。  
2. **gdown 文件夹（网络稳定时）：**

   ```powershell
   python -m gdown --folder "https://drive.google.com/drive/folders/1hn0sXLZ5yJcxtmuY-ItQfYD7hBtHwt7A" `
     -O pretrained\market1501 --proxy http://127.0.0.1:7897
   ```

3. **分卷 ID 列表：** 若文件夹 API 失败，可用 `gdown --json` 或 Drive 页面列出各文件 ID，再对每个 ID 执行 `gdown "https://drive.google.com/uc?id=<FILE_ID>"`（团队可在本地维护 manifest，**勿提交 Cookie**）。

### 5.4 7-Zip 完整性测试与解压

安装 [7-Zip](https://www.7-zip.org/) 后：

```powershell
& "C:\Program Files\7-Zip\7z.exe" t pretrained\market1501\market_resnet50_model_120_rank1_945.zip.001
```

应显示 **Type = Split**, **Volumes = 45**, **Everything is Ok**。  
解压到临时目录（勿覆盖已有 `.pth`  unless 已确认损坏）：

```powershell
$tmp = "pretrained\market1501\_extract_tmp"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
& "C:\Program Files\7-Zip\7z.exe" x "pretrained\market1501\market_resnet50_model_120_rank1_945.zip.001" "-o$tmp" -y
```

压缩包内文件名为 **`market_resnet50_model_120_rank1_945.pth`**（约 **100486291** 字节）。  
官方 `TEST.WEIGHT` 示例文件名为 **`resnet50_model_120.pth`** — 复制并重命名即可：

```powershell
Copy-Item "$tmp\market_resnet50_model_120_rank1_945.pth" `
  "pretrained\market1501\resnet50_model_120.pth"
```

**不要** 对分卷做 `copy /b` 手工拼接（格式为 7-Zip Split，非简单二进制拼接）。

### 5.5 权重加载自检（可选）

```powershell
python -c "import torch; w=torch.load('pretrained/market1501/resnet50_model_120.pth', map_location='cpu', weights_only=False); print(type(w), len(w) if hasattr(w,'__len__') else w)"
```

期望：`OrderedDict`，约 **324** 个 `base.*` 键。

---

## 6. 运行官方测试

### 6.1 配置说明

| 键 | 值 | 含义 |
|----|-----|------|
| `configs/softmax_triplet_with_center.yml` | 基础配置 | triplet + center 训练配置；测试时仅用模型与 TEST 段 |
| `MODEL.PRETRAIN_CHOICE` | `self` | 跳过 ImageNet 预训练加载 |
| `TEST.WEIGHT` | `.../resnet50_model_120.pth` | 作者 checkpoint |
| `TEST.NECK_FEAT` | `after` | BNNeck 之后特征 |
| `TEST.FEAT_NORM` | `yes` | L2 归一化（cosine 评测） |
| `TEST.RE_RANKING` | `no` | 与 `Test-all_tricks-tri_center-feat_after_bn-cos-market.sh` 一致 |
| `DATASETS.ROOT_DIR` | `$ReidRepoRoot/data` | 数据集根 |
| `DATALOADER.NUM_WORKERS` | `0` | Windows 推荐 |
| `OUTPUT_DIR` | 任意可写目录 | 保存 `log.txt` |

### 6.2 PowerShell 脚本（推荐）

在 **nwueyes** 仓库根目录：

```powershell
.\scripts\reid-strong-baseline\test_market1501.ps1 `
  -ReidRepoRoot "D:\path\to\reid-strong-baseline" `
  -PythonExe "D:\path\to\reid-strong-baseline-py310\Scripts\python.exe"
```

环境变量（可选）：

| 变量 | 含义 |
|------|------|
| `REID_REPO_ROOT` | 默认 `-ReidRepoRoot` |
| `REID_PYTHON` | 默认 `-PythonExe` |
| `REID_DATA_ROOT` | 覆盖 `DATASETS.ROOT_DIR` |
| `REID_WEIGHT` | 覆盖 `TEST.WEIGHT` |
| `REID_OUTPUT_DIR` | 覆盖日志输出目录 |
| `HTTP_PROXY` / `HTTPS_PROXY` | 仅影响你主动执行的下载命令，脚本本身不设置 |

### 6.3 手工命令（与验收一致）

在 `$ReidRepoRoot` 下：

```powershell
python tools\test.py `
  --config_file configs/softmax_triplet_with_center.yml `
  MODEL.DEVICE_ID "('0')" `
  DATASETS.NAMES "('market1501')" `
  DATASETS.ROOT_DIR "('D:/path/to/reid-strong-baseline/data')" `
  MODEL.PRETRAIN_CHOICE "('self')" `
  TEST.WEIGHT "('D:/path/to/reid-strong-baseline/pretrained/market1501/resnet50_model_120.pth')" `
  TEST.NECK_FEAT "('after')" `
  TEST.FEAT_NORM "('yes')" `
  OUTPUT_DIR "('D:/path/to/reid-strong-baseline/outputs/reproduction_acceptance/run_manual')" `
  DATALOADER.NUM_WORKERS "(0)"
```

路径请使用 **正斜杠** 或 yacs 可解析的形式。  
成功结束时日志含 `Validation Results`、`mAP`、`CMC curve, Rank-1`。

### 6.4 本机已记录指标（参考）

见 [ACCEPTANCE_20261012.md](./ACCEPTANCE_20261012.md)。README 中 Market1501 Rank-1 约 **94.5%** 量级；本机 **94.6%**。因 ignite / PyTorch 版本与 OS 差异，**不保证**每台机器完全一致。

---

## 7. 常见问题

**Q: `FileURLRetrievalError` / Google Drive SSL EOF？**  
A: 多为网络或 Drive 限流。确认代理仅在本机 session 设置；对 **单文件 ID** 重试；文件夹 listing 失败时改用浏览器下载分卷。不要用文件夹 ID 当单文件下载。

**Q: `ModuleNotFoundError: torch._six`（ignite）？**  
A: 使用 **pytorch-ignite 0.3.0**，或降级 PyTorch（本指南未验证）。

**Q: DataLoader 卡住或报错（Windows）？**  
A: `DATALOADER.NUM_WORKERS "(0)"`。

**Q: gallery 图片数与磁盘文件数不一致？**  
A: 官方 loader 只统计有效 ID；以日志中 `Dataset statistics` 为准。

**Q: `addmm_` deprecated warning？**  
A: 来自 `utils/reid_metric.py`，不影响本次推理完成。

---

## 8. Git 与保密

勿提交：Market1501 图像、zip、`.pth`、45 分卷、venv、`outputs/` 大日志、Cookie、代理密码。  
nwueyes 父仓库 `.gitignore` 已增加常见 Re-ID 路径模式（见仓库根 `.gitignore`）。
