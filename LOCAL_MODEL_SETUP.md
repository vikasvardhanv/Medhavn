# Local On-Device Model Setup (Intuio)

This project is wired for an MLX-first runtime with safe fallback.

## Current runtime behavior

- If `MLX` + `MLXLLM` are available, app selects `IntuioMLXNoteEngine`.
- If not available, app falls back to deterministic local notes (`IntuioMicroSLMNoteEngine`).
- Runtime selection is automatic in `Storage/IntuioOnDeviceLLM.swift`.

## Recommended tiny model

- `HuggingFaceTB/SmolLM2-360M-Instruct`

## Integration steps

1. Add Swift package dependencies to Xcode project:
   - `https://github.com/ml-explore/mlx-swift`
2. Include the MLX model load + generation call in `generateWithMLX(prompt:)`.
3. Keep note guardrails:
   - No diagnosis
   - No treatment changes
   - Short patient-friendly summary only
4. Benchmark on device and set generation limits for latency and battery.

## Files

- Runtime factory: `Storage/IntuioOnDeviceLLM.swift`
- Existing deterministic fallback: `Storage/ProactiveInsightsEngine.swift`
- App wiring: `AppState.swift`
