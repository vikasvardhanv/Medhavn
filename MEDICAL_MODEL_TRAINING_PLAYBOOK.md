# Medical Model Training Playbook (Intuio)

This app now supports on-device inference with MLX runtime integration.  
Training should happen **offline/server-side**, then deploy quantized weights to the mobile app.

## 1) Define the model task (narrow first)

For this product, start with one task only:
- `daily_patient_note_summarization` from medication schedule + logs + safety flags.

Avoid broad "medical assistant" behavior in v1.

## 2) Data and compliance requirements

Before training:
- Remove PHI and direct identifiers (names, emails, phone, MRN, addresses).
- De-identify free text (NER scrub + manual audits).
- Keep a documented data provenance log.
- Track patient consent and permissible use.
- Keep policy boundaries: no diagnosis, no treatment recommendation.

Recommended split:
- Train 80%
- Validation 10%
- Holdout test 10%

## 3) Dataset format

Use JSONL with instruction-style examples.

Example:
```json
{"instruction":"Write a concise daily patient note in under 80 words.","input":"Medication: Metformin 500 mg BID. Taken 1/2 today. Next dose 8:00 PM. Flags: none. PRN: none. Reminders enabled.","output":"Daily note: You have taken 1 of 2 scheduled doses today, with one dose due at 8:00 PM. No active safety flags were detected. Continue as scheduled and log your evening dose."}
```

Keep outputs:
- concise
- non-diagnostic
- action-safe
- readable for patients

## 4) Base model choice

Start with a small instruct model for mobile deployment:
- `mlx-community/Qwen2-0.5B-Instruct-4bit` (current app default)

## 5) Fine-tuning strategy

Use parameter-efficient tuning (LoRA/QLoRA), not full fine-tune.

High-level flow:
1. Convert/prepare dataset.
2. Train LoRA adapters on curated medical-note task.
3. Evaluate on holdout with automatic + clinician review.
4. Merge/fuse adapters if needed.
5. Quantize for on-device inference.

## 6) Evaluation gates (must pass)

Track:
- Hallucination rate
- Safety policy violations (diagnosis/treatment advice)
- Factual consistency against structured inputs
- Readability and brevity targets

Define a release gate, e.g.:
- Safety violation rate < 0.5%
- Hallucination rate < 2%
- Clinician acceptance > 95% on sampled set

## 7) Deploy to app

In app runtime:
- Keep deterministic fallback enabled.
- Add timeout + fallback when model load/generation fails.
- Version model (`model_id`, `revision`) and log locally.

## 8) Continuous improvement loop

- Collect user corrections (opt-in only).
- Re-label hard failure cases monthly.
- Retrain adapters on delta dataset.
- Ship incremental model versions with rollback support.

## 9) Minimal training stack recommendation

Use MLX LM training tooling from Apple MLX ecosystem:
- `ml-explore/mlx-swift-lm` (runtime/reference)
- `ml-explore/mlx-examples` (LoRA patterns)

Practical recommendation:
- Train in Python MLX/LoRA pipeline for speed.
- Export MLX-compatible weights.
- Validate in this iOS app via `IntuioMLXNoteEngine`.

## 10) Safety statement for product

Keep this explicit in UI + docs:
- The model provides educational summaries only.
- It does not diagnose, prescribe, or replace clinician guidance.
