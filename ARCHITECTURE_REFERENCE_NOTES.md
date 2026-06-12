# Medhavn Reference Architecture Notes (Clean-Room)

This project can reference open-source apps for **architecture patterns only**. It must not copy GPL source into commercial code.

## Repos reviewed previously (for architecture study)
- MediTrak (GPL-2.0)
- calendula (GPL-3.0)
- rxdroid (GPL-3.0)
- Mediminder (no explicit license found in repo metadata)
- openmhealth/schemas (Apache-2.0)

## Architecture patterns extracted
1. Layered separation
   - UI layer
   - scheduling/logic layer
   - persistence layer
   - notification/export utilities

2. Data entities
   - medication plan
   - schedule events
   - dose history/adherence log
   - settings/preferences

3. Scheduler responsibilities
   - compute next dose window
   - daily projections
   - interval checks / caps
   - PRN handling as a separate path

4. Safety constraints
   - hard caps for daily maxes
   - minimum interval checks
   - warnings on ambiguous inputs

5. Export & privacy
   - local data persistence
   - optional export/share
   - explicit privacy communication

## How Medhavn applies these safely
- Implements `MedicationLogicEngine` from scratch in Swift.
- Uses independent parser/rules/schedule/checker/explanation modules.
- Uses local SQLite persistence with app-owned schema.
- Uses app-authored SwiftUI screens and PDF exporter.
- Uses openmhealth schemas only as conceptual interoperability guidance.

## License safety policy for this repo
- No direct copying of GPL source, tests, assets, or strings.
- No transliteration (language-to-language copying) from GPL code.
- Any future external dependency must be reviewed for license compatibility.
