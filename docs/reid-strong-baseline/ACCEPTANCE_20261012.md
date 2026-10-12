# Inference acceptance summary (local run)

**Run label:** `run_20261012_213500`  
**Date:** 2026-10-12  

This file is a **sanitized summary** for colleagues. Full console logs were kept locally only (not in Git).

## Scope

Official `tools/test.py` on Market1501 with author pretrained weights; no training, no re-ranking.

## Environment (verified once)

- Windows, Python 3.10 venv  
- PyTorch 2.6.0+cu124, torchvision 0.21.0+cu124, CUDA available  
- pytorch-ignite **0.3.0** (upstream README 0.1.2 fails on torch 2.6 without patches)  

## Config overrides

- `configs/softmax_triplet_with_center.yml`  
- `MODEL.PRETRAIN_CHOICE=self`  
- `TEST.WEIGHT` → `resnet50_model_120.pth`  
- `TEST.NECK_FEAT=after`, `TEST.FEAT_NORM=yes`, `TEST.RE_RANKING=no`  
- `DATALOADER.NUM_WORKERS=0` (Windows)  

## Dataset loader statistics

| subset | # ids | # images |
|--------|-------|----------|
| train | 751 | 12936 |
| query | 750 | 3368 |
| gallery | 751 | 15913 |

## Metrics (official evaluator)

| Metric | Value |
|--------|--------|
| mAP | 85.9% |
| Rank-1 | 94.6% |
| Rank-5 | 98.2% |
| Rank-10 | 99.0% |

## Notes

- Weights archive: 45 split volumes → inner `market_resnet50_model_120_rank1_945.pth` → rename/copy to `resnet50_model_120.pth` for `TEST.WEIGHT`.  
- Market1501 zip: **152733771** bytes, MD5 `65005ab7d12ec1c44de4eeafe813e68a`.  
- **Cross-machine reproduction via nwueyes docs alone has not been re-verified on a clean host.**
