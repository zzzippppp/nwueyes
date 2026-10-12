# Strong Baseline + BNNeck — Market1501 推理复现

本文档说明如何在 **Windows**（其他平台可参考命令）上，基于官方 [reid-strong-baseline](https://github.com/michuanhaohao/reid-strong-baseline) 源码与作者发布的 Market1501 预训练权重，运行 **`tools/test.py`** 完成一次官方指标评测。

**关联仓库：**

| 仓库 | 地址 |
|------|------|
| nwueyes（本文档所在） | `https://github.com/zzzippppp/nwueyes.git` |
| 上游 Strong Baseline | `https://github.com/michuanhaohao/reid-strong-baseline.git` |

详细步骤见 **[REPRODUCTION.md](./REPRODUCTION.md)**。一键测试脚本（路径可配置）：[`scripts/reid-strong-baseline/test_market1501.ps1`](../../scripts/reid-strong-baseline/test_market1501.ps1)。

---

## 论文与引用

- **论文：** Luo, H., Gu, Y., Liao, X., Lai, S., Jiang, W. *Bag of Tricks and A Strong Baseline for Deep Person Re-identification.* CVPR Workshops, 2019.
- **代码：** [michuanhaohao/reid-strong-baseline](https://github.com/michuanhaohao/reid-strong-baseline)
- **BNNeck：** 测试时使用 `TEST.NECK_FEAT=after`、L2 归一化特征（与官方 `Test-all_tricks-tri_center-feat_after_bn-cos-market.sh` 一致）。

---

## 复现范围（务必区分）

| 类别 | 状态 | 说明 |
|------|------|------|
| **官方预训练 + Market1501 推理（mAP / Rank-k）** | **本机已验收（2026-10-12）** | 使用 `configs/softmax_triplet_with_center.yml`，`RE_RANKING=no`，见 [ACCEPTANCE_20261012.md](./ACCEPTANCE_20261012.md)。 |
| **跨机器 / 干净环境按文档复现** | **尚未在 CI 或第二台机器验证** | 克隆仓库后需自行准备数据、权重与环境；**不能**因单次本机成功即宣称全员可复现。 |
| **从头训练、全部消融、DukeMTMC、re-ranking 脚本** | **不在范围** | 见 REPRODUCTION.md「未覆盖范围」。 |
| **与 nwueyes 考勤 / ByteTrack 集成** | **不在范围** | 独立研究复现；ByteTrack 文档见 [../bytetrack-reproduction/README.md](../bytetrack-reproduction/README.md)。 |

---

## 推荐目录布局

官方代码 **不** 作为 nwueyes 子模块提交；请在本地 clone，并与 nwueyes **并列** 或放在统一工作区下（团队可自定，脚本通过参数指定根目录）：

```text
your-workspace/
├── nwueyes/                          # 本 Git 仓库（文档 + 脚本）
│   ├── docs/reid-strong-baseline/
│   └── scripts/reid-strong-baseline/
├── external/                         # 示例：与 nwueyes 同级的 external（可选）
│   ├── reid-strong-baseline/         # git clone 官方仓库 @ 固定 commit
│   └── reid-strong-baseline-py310/   # 独立 venv（勿提交）
```

**建议固定的上游 commit（与本次验收一致）：**

```text
3da7e6f03164a92e696cb6da059b1cd771b0346d
```

---

## 快速开始

1. Clone 官方仓库并 checkout 上述 commit（见 REPRODUCTION.md）。
2. 创建 Python 3.10 虚拟环境，安装 [requirements-reproduction.txt](./requirements-reproduction.txt)（含 PyTorch CUDA 说明）。
3. 按 REPRODUCTION.md 下载 **Market1501** 与 **Google Drive 权重分卷**，校验 MD5/大小，7-Zip 解压得到 `resnet50_model_120.pth`。
4. 运行测试脚本：

```powershell
cd nwueyes
.\scripts\reid-strong-baseline\test_market1501.ps1 `
  -ReidRepoRoot "D:\work\external\reid-strong-baseline" `
  -PythonExe "D:\work\external\reid-strong-baseline-py310\Scripts\python.exe"
```

5. 查看控制台与 `-OutputDir` 下的 `log.txt` 中的 **mAP / Rank-1**。

---

## 本目录文件

| 文件 | 说明 |
|------|------|
| [README.md](./README.md) | 本页：范围与快速开始 |
| [REPRODUCTION.md](./REPRODUCTION.md) | 完整复现步骤与 FAQ |
| [requirements-reproduction.txt](./requirements-reproduction.txt) | 已验证 Python 依赖（推理） |
| [ACCEPTANCE_20261012.md](./ACCEPTANCE_20261012.md) | 本机验收指标摘要（无大日志） |

---

## 已验证指标（本机，仅供参考）

| 指标 | 值 |
|------|-----|
| mAP | 85.9% |
| Rank-1 | 94.6% |
| Rank-5 | 98.2% |
| Rank-10 | 99.0% |

环境与依赖差异（如 **pytorch-ignite 0.3.0** 替代 README 的 0.1.2）见 REPRODUCTION.md；**不等于**复现论文全部实验结论。
