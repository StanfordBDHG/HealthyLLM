#!/usr/bin/env bash
# Export ECG-QA CoT test sample 0 for iOS/Python parity validation.
# Requires: OpenTSLM repo at ~/OpenTSLM, OpenTSLMMLX venv, PTB-XL + CoT data (auto-downloaded on first run).
set -euo pipefail

OPENTSLMMLX="${OPENTSLMMLX:-$HOME/Documents/GitHub/OpenTSLMMLX}"
OPENTSLM_SRC="${OPENTSLM_SRC:-$HOME/OpenTSLM/src}"
OUT_JSON="${OUT_JSON:-$HOME/Documents/HealthyLLM/HealthyLLM/Supporting Files/OpenTSLM/ecg_qa_cot_test_0.json}"
OUT_TXT="${OUT_TXT:-$OPENTSLMMLX/ecg_golden_output.txt}"

cd "$OPENTSLMMLX"
source .venv/bin/activate
pip install -q wfdb datasets

python inference_ecg.py \
  --split test \
  --sample-idx 0 \
  --max-new-tokens 200 \
  --opentslm-src "$OPENTSLM_SRC" \
  --export-json "$OUT_JSON" \
  --out "$OUT_TXT"

echo "Golden text: $OUT_TXT"
echo "iOS bundle JSON: $OUT_JSON"
