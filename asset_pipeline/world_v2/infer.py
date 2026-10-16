"""Runs in the existing ComfyUI Python environment; never installs dependencies."""
from __future__ import annotations
import argparse
import importlib.metadata
import json
import os
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', type=Path, required=True)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--target', type=Path)
    args = parser.parse_args()
    os.environ['HF_HUB_OFFLINE'] = '1'
    os.environ['TRANSFORMERS_OFFLINE'] = '1'
    import torch
    from transformers import AutoModelForImageSegmentation
    from torchvision import transforms
    from PIL import Image
    # CPU keeps this separate cleanup pass from competing with SDXL's GPU memory.
    torch.set_num_threads(max(1, min(8, os.cpu_count() or 1)))
    model = AutoModelForImageSegmentation.from_pretrained(
        str(args.model.resolve()), trust_remote_code=True, local_files_only=True,
        use_safetensors=True).float().cpu().eval()
    if args.source is None:
        print(json.dumps({'model_load': 'PASS', 'device': 'cpu', 'dtype': 'float32'}))
        return
    if args.target is None or args.target.exists():
        raise RuntimeError('OUTPUT_MISSING_OR_ALREADY_EXISTS')
    image = Image.open(args.source).convert('RGB')
    transform = transforms.Compose([
        transforms.Resize((1024, 1024)), transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])])
    with torch.inference_mode():
        mask = model(transform(image).unsqueeze(0))[-1].sigmoid()[0].squeeze().cpu()
    alpha = transforms.ToPILImage()(mask).resize(image.size, Image.Resampling.LANCZOS)
    if alpha.getextrema()[0] >= 250 or alpha.getextrema()[1] <= 5:
        raise RuntimeError('BACKGROUND_MASK_EMPTY_OR_OPAQUE')
    image.putalpha(alpha)
    args.target.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.target, format='PNG')
    print(json.dumps({'inference': 'PASS', 'device': 'cpu', 'dtype': 'float32',
                      'torch': importlib.metadata.version('torch')}))


if __name__ == '__main__':
    main()
