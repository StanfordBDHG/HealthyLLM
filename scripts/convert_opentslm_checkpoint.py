#!/usr/bin/env python3
"""
Convert an OpenTSLM-SP PyTorch `.pt` checkpoint (as published on Hugging Face,
e.g. `OpenTSLM/llama-3.2-1b-ecg-sp/model_checkpoint.pt`) into the three MLX
safetensors files the HealthyLLM Swift loader expects:

    mlx-checkpoint.encoder.safetensors    (TransformerCNNEncoder weights)
    mlx-checkpoint.projector.safetensors  (MLPProjector weights)
    mlx-checkpoint.lora.safetensors       (PEFT LoRA adapters → MLX layout)

Logic mirrors OpenTSLM-MLX's `_convert_encoder_weights` / `_convert_projector_weights`
in `src/opentslm_sp.py` so the resulting files are byte-compatible with the
existing sleep checkpoints already in the app bundle.

USAGE
-----
    pip install torch safetensors numpy
    python scripts/convert_opentslm_checkpoint.py \
        path/to/model_checkpoint.pt \
        --out-dir "HealthyLLM/Supporting Files/OpenTSLM" \
        [--prefix mlx-checkpoint.ecg]

If --prefix is given, files are named e.g. `mlx-checkpoint.ecg.encoder.safetensors`
so ECG checkpoints can sit alongside the sleep ones without overwriting them.
Without --prefix the default `mlx-checkpoint.{encoder,projector,lora}.safetensors`
names are used (these will REPLACE any existing sleep checkpoints).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors.numpy import save_file


# ----- Encoder -----------------------------------------------------------------

def convert_encoder(state_dict: dict) -> dict:
    """PyTorch TransformerCNNEncoder state_dict → MLX-layout numpy dict."""
    out: dict[str, np.ndarray] = {}

    # Conv1d: PyTorch [C_out, C_in, K] -> MLX [C_out, K, C_in]
    out["patch_embed.weight"] = state_dict["patch_embed.weight"].cpu().float().numpy().transpose(0, 2, 1)
    out["pos_embed"] = state_dict["pos_embed"].cpu().float().numpy()
    out["input_norm.weight"] = state_dict["input_norm.weight"].cpu().float().numpy()
    out["input_norm.bias"] = state_dict["input_norm.bias"].cpu().float().numpy()

    num_layers = sum(
        1 for k in state_dict
        if k.startswith("encoder.layers.") and k.endswith(".norm1.weight")
    )
    if num_layers == 0:
        raise RuntimeError("No encoder layers found — wrong state_dict shape?")

    for i in range(num_layers):
        pt_pfx = f"encoder.layers.{i}"
        mx_pfx = f"layers.{i}"

        # PyTorch packs Q/K/V into a single in_proj — split it.
        in_w = state_dict[f"{pt_pfx}.self_attn.in_proj_weight"].cpu().float().numpy()
        in_b = state_dict[f"{pt_pfx}.self_attn.in_proj_bias"].cpu().float().numpy()
        d = in_w.shape[1]
        out[f"{mx_pfx}.self_attn.query_proj.weight"] = in_w[:d]
        out[f"{mx_pfx}.self_attn.key_proj.weight"] = in_w[d:2 * d]
        out[f"{mx_pfx}.self_attn.value_proj.weight"] = in_w[2 * d:]
        out[f"{mx_pfx}.self_attn.query_proj.bias"] = in_b[:d]
        out[f"{mx_pfx}.self_attn.key_proj.bias"] = in_b[d:2 * d]
        out[f"{mx_pfx}.self_attn.value_proj.bias"] = in_b[2 * d:]

        for name in ("out_proj",):
            out[f"{mx_pfx}.self_attn.{name}.weight"] = (
                state_dict[f"{pt_pfx}.self_attn.{name}.weight"].cpu().float().numpy()
            )
            out[f"{mx_pfx}.self_attn.{name}.bias"] = (
                state_dict[f"{pt_pfx}.self_attn.{name}.bias"].cpu().float().numpy()
            )

        for name in ("linear1", "linear2", "norm1", "norm2"):
            for param in ("weight", "bias"):
                out[f"{mx_pfx}.{name}.{param}"] = (
                    state_dict[f"{pt_pfx}.{name}.{param}"].cpu().float().numpy()
                )

    return out


# ----- Projector ---------------------------------------------------------------

def convert_projector(state_dict: dict) -> dict:
    """PyTorch MLPProjector state_dict → MLX-layout numpy dict."""
    return {
        "norm.weight": state_dict["projector.0.weight"].cpu().float().numpy(),
        "norm.bias":   state_dict["projector.0.bias"].cpu().float().numpy(),
        "linear.weight": state_dict["projector.1.weight"].cpu().float().numpy(),
        "linear.bias":   state_dict["projector.1.bias"].cpu().float().numpy(),
    }


# ----- LoRA --------------------------------------------------------------------

_LORA_KEY = re.compile(r"^base_model\.model\.(.+)\.(lora_[AB])\.default\.weight$")


def convert_lora(state_dict: dict) -> dict:
    """PEFT LoRA state → MLX-layout numpy dict.

    PEFT stores `base_model.model.<path>.lora_A.default.weight` of shape [r, in]
    and `lora_B` of shape [out, r]. MLX's `LoRALinear` wants `<path>.lora_a` of
    shape [in, r] and `<path>.lora_b` of shape [r, out] — so we strip the PEFT
    prefix, lowercase A/B, and transpose.
    """
    out: dict[str, np.ndarray] = {}
    for key, tensor in state_dict.items():
        m = _LORA_KEY.match(key)
        if not m:
            continue
        layer_path, ab = m.group(1), m.group(2).lower()
        if not layer_path.startswith("model."):
            layer_path = f"model.{layer_path}"
        mlx_key = f"{layer_path}.{ab}"
        out[mlx_key] = tensor.cpu().float().numpy().T  # PEFT [r,in]/[out,r] → MLX [in,r]/[r,out]
    if not out:
        raise RuntimeError("No LoRA tensors matched the PEFT key pattern — wrong state_dict?")
    return out


# ----- Driver ------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("checkpoint", type=Path, help="Path to model_checkpoint.pt")
    ap.add_argument("--out-dir", type=Path, required=True, help="Directory to write the safetensors files to")
    ap.add_argument("--prefix", default="mlx-checkpoint",
                    help='File prefix (default: "mlx-checkpoint"). Use "mlx-checkpoint.ecg" to keep'
                         " ECG files alongside the existing sleep ones.")
    args = ap.parse_args()

    if not args.checkpoint.exists():
        ap.error(f"checkpoint not found: {args.checkpoint}")
    args.out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading {args.checkpoint} (this can take ~5–10 s for a 164 MB pickle) …")
    # weights_only=False because PEFT pickles include LoraConfig objects.
    ckpt = torch.load(args.checkpoint, map_location="cpu", weights_only=False)

    required = ("encoder_state", "projector_state")
    missing = [k for k in required if k not in ckpt]
    if missing:
        sys.exit(f"checkpoint is missing required keys: {missing} — got {list(ckpt.keys())}")

    enc = convert_encoder(ckpt["encoder_state"])
    proj = convert_projector(ckpt["projector_state"])
    print(f"  encoder tensors:   {len(enc)}")
    print(f"  projector tensors: {len(proj)}")

    enc_path = args.out_dir / f"{args.prefix}.encoder.safetensors"
    proj_path = args.out_dir / f"{args.prefix}.projector.safetensors"
    save_file(enc, str(enc_path))
    save_file(proj, str(proj_path))
    print(f"  ✓ wrote {enc_path}")
    print(f"  ✓ wrote {proj_path}")

    lora_state = ckpt.get("lora_state")
    if lora_state:
        lora = convert_lora(lora_state)
        lora_path = args.out_dir / f"{args.prefix}.lora.safetensors"
        save_file(lora, str(lora_path))
        print(f"  lora tensors:      {len(lora)}")
        print(f"  ✓ wrote {lora_path}")
    else:
        print("  (no lora_state in checkpoint — skipping LoRA file)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
