#!/usr/bin/env python3
"""Export iOS ECG-QA CoT assets from the full OpenTSLM loader.

Produces:
  - ecg_qa_cot_<split>.csv prefix (metadata rows only)
  - ecg_qa_waveforms/<ecg_id>.json (PTB-XL waveforms, loader-processed, lazy-loaded on iOS)
  - ecg_qa_template_answers.json

iOS reads the CSV like SleepEDFDataset, indexes one row, and loads only that ecg_id waveform.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

DEFAULT_OPENTSLM_SRC = Path.home() / "OpenTSLM" / "src"


def ensure_opentslm_import(opentslm_src: Path) -> None:
    src = opentslm_src.expanduser().resolve()
    if not src.exists():
        raise FileNotFoundError(
            f"OpenTSLM source not found at {src}. "
            "Clone https://github.com/SchmiedmayerLab/OpenTSLM or pass --opentslm-src."
        )
    if str(src) not in sys.path:
        sys.path.insert(0, str(src))


def split_csv_name(split: str) -> str:
    if split == "validation":
        return "ecg_qa_cot_val.csv"
    return f"ecg_qa_cot_{split}.csv"


def export_ios_assets(
    opentslm_src: Path,
    split: str,
    max_rows: int,
    out_dir: Path,
) -> None:
    ensure_opentslm_import(opentslm_src)

    try:
        import wfdb  # noqa: F401
    except ImportError as err:
        raise ImportError("Install wfdb: pip install wfdb") from err

    from opentslm.time_series_datasets.ecg_qa.ECGQACoTQADataset import ECGQACoTQADataset
    from opentslm.time_series_datasets.ecg_qa.ecgqa_cot_loader import (
        ECG_QA_COT_DIR,
        load_ecg_qa_cot_splits,
    )

    print("Loading ECG-QA CoT splits (downloads data on first run)...")
    train, val, test = load_ecg_qa_cot_splits()
    split_map = {"train": train, "validation": val, "test": test}
    rows = split_map[split]
    if not rows:
        raise RuntimeError(f"Split {split!r} is empty")

    limited_rows = rows.select(range(min(max_rows, len(rows))))
    unique_ecg_ids = sorted({row["ecg_id"][0] for row in limited_rows})

    formatter = ECGQACoTQADataset.__new__(ECGQACoTQADataset)
    formatter.EOS_TOKEN = ""

    template_ids = {int(row["template_id"]) for row in limited_rows}

    waveforms_dir = out_dir / "ecg_qa_waveforms"
    waveforms_dir.mkdir(parents=True, exist_ok=True)

    print(f"Processing PTB-XL waveforms for {len(unique_ecg_ids)} unique ecg_id values...")
    for ecg_id in unique_ecg_ids:
        source_row = next(row for row in limited_rows if row["ecg_id"][0] == ecg_id)
        formatted = formatter._format_sample(source_row)
        payload = {
            "time_series": [list(map(float, lead)) for lead in formatted["time_series"]],
            "time_series_text": formatted["time_series_text"],
        }
        (waveforms_dir / f"{ecg_id}.json").write_text(json.dumps(payload), encoding="utf-8")

    template_answers: dict[str, list[str]] = {}
    for template_id in sorted(template_ids):
        answers = ECGQACoTQADataset.get_possible_answers_for_template(template_id)
        template_answers[str(template_id)] = answers

    out_dir.mkdir(parents=True, exist_ok=True)

    source_csv = Path(ECG_QA_COT_DIR) / split_csv_name(split)
    dest_csv = out_dir / split_csv_name(split)
    print(f"Writing CSV prefix ({max_rows} rows) to {dest_csv}...")
    with source_csv.open(newline="", encoding="utf-8") as src, dest_csv.open(
        "w", newline="", encoding="utf-8"
    ) as dst:
        reader = csv.reader(src)
        writer = csv.writer(dst)
        header = next(reader)
        writer.writerow(header)
        for idx, record in enumerate(reader):
            if idx >= max_rows:
                break
            writer.writerow(record)

    template_path = out_dir / "ecg_qa_template_answers.json"
    template_path.write_text(
        json.dumps({"template_answers": template_answers}, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote waveforms directory to {waveforms_dir.resolve()}")
    print(f"Wrote template answers to {template_path.resolve()}")
    print(f"Unique ecg_ids: {len(unique_ecg_ids)}; template answers: {len(template_answers)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--split", default="test", choices=["train", "validation", "test"])
    parser.add_argument("--max-rows", type=int, default=500)
    parser.add_argument("--opentslm-src", default=str(DEFAULT_OPENTSLM_SRC))
    parser.add_argument(
        "--out-dir",
        default=str(
            Path(__file__).resolve().parents[1]
            / "HealthyLLM"
            / "Supporting Files"
            / "OpenTSLM"
        ),
    )
    args = parser.parse_args()

    export_ios_assets(
        opentslm_src=Path(args.opentslm_src),
        split=args.split,
        max_rows=args.max_rows,
        out_dir=Path(args.out_dir),
    )


if __name__ == "__main__":
    main()
