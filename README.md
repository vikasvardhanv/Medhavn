# Medhavn

Medication Logic Engine + Patient Execution App (SwiftUI + local SQLite).

## Scope implemented
- Add plan from pasted text, scanned text (OCR), uploaded text/PDF, or manual input
- Add plan from pasted text, scanned text (OCR), uploaded text/PDF/image, or manual input
- Parse into structured medication fields
- Flag ambiguity and safety issues
- Generate day-by-day schedule with taper/cycle/PRN limits
- Today view with next action, remaining doses, PRN allowance, hard stops
- Proactive assistant suggestions for safety, reminder readiness, and adherence risks
- Local notification reminders for upcoming doses (when permission is granted)
- Dose logging with timestamp
- PDF adherence summary export
- 60-day trial with upgrade flow (warnings remain available)
- Privacy controls and educational disclaimer

## Project layout
- `Sources/MedicationLogicEngine`: parser, rules, scheduler, checker, explanations
- `Tests/MedicationLogicEngineTests`: parser + schedule unit tests
- `MedhavnApp.swift`, `AppState.swift`: app entry + state container
- `Features/`, `Models/`, `Storage/`: SwiftUI screens, app models, SQLite store
- `Medhavn.xcworkspace`: root workspace for opening in Xcode

## Run tests
```bash
swift test
```

## iOS app setup
Open `Medhavn.xcworkspace` in Xcode, then add an iOS App target named `Medhavn` and attach the existing root source files (`MedhavnApp.swift`, `AppState.swift`, `Features`, `Models`, `Storage`).

## Supabase setup
This app supports Supabase Auth directly from the iOS client using:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Set them via `project.yml` (`INFOPLIST_KEY_SUPABASE_URL`, `INFOPLIST_KEY_SUPABASE_ANON_KEY`).

For complete Coolify + Cloudflare + SQL/RLS steps, see `SUPABASE_SETUP.md`.

## User data entry flow
- Open Add Plan
- Choose input method (paste, scan, or manual)
- Optional: use **Upload Text or PDF** to import report/instruction text from Files
- Tap **Build Medication Plan**
- Review parsed fields, safety flags, and patient-ready directions

## Safety constraints
- Educational planning tool only; not medical advice.
- Do not diagnose conditions.
- For imaging uploads, process only report text (radiology/lab report text extraction and terminology explanation).
- Require pharmacist/clinician confirmation when instructions are ambiguous.

## License note
See `ARCHITECTURE_REFERENCE_NOTES.md` for clean-room reference policy.
