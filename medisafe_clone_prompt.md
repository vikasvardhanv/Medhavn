# Medisafe App Clone: UI & Features Prompt

Based on an analysis of the Medisafe app overview video, here is a comprehensive prompt you can use to instruct an AI or developer to build a similar application.

***

**System Role & Objective:**
Act as an expert Frontend Developer and UX/UI Designer. Your task is to build a healthcare and medication management web application inspired by the Medisafe ecosystem. The application should not just be a visual clone but must implement the core functional logic demonstrated in the app.

**1. General UI/UX & Theming**
*   **Aesthetic & Vibe**: The app must feel professional, clean, and trustworthy. Use a healthcare-focused minimalist design.
*   **Color Palette**: Primarily use a white and light grey background. Use a vibrant, reassuring blue for primary actions, buttons, and highlights. Use a clear, accessible red for warnings, alerts, or missed doses.
*   **Typography & Shapes**: High-contrast, highly readable modern sans-serif fonts (e.g., Inter, Roboto). Components should use rounded corners and subtle drop shadows to create depth, making the interface approachable.
*   **Navigation**: Implement a sticky 5-tab bottom navigation bar containing:
    1.  **Pillbox** (Home)
    2.  **Updates**
    3.  **Report**
    4.  **Med Cabinet**
    5.  **More**

**2. Core Screens & Components**

*   **Screen 1: The Pillbox (Main Dashboard)**
    *   **Multi-Profile Header**: At the very top, implement a profile switcher containing avatars/icons. Users must be able to swipe or tap to switch between different family members' schedules cleanly. Include a date navigator below it to jump between days.
    *   **Time-Block Layout**: The main body should be divided into 4 visual quadrants or distinct lists corresponding to daily time blocks: Morning, Afternoon, Evening, and Night.
    *   **Medication Cards**: Within each block, display medications using large, interactive cards. Each card must show:
        *   Medication Name
        *   Dosage amounts (e.g., 1 pill, 50mg)
        *   A custom visual icon representing the pill (shape and color).
    *   **Interaction**: Users should be able to tap a card to mark a dose as "Taken" (with a satisfying micro-animation or checkmark) or swipe to "Skip."

*   **Screen 2: The Med Cabinet (Inventory)**
    *   A comprehensive list view of all active medications.
    *   Each entry should display the remaining pill count and refill status.

*   **Screen 3: Updates (Notification Center)**
    *   A feed-style layout displaying chronologically ordered alerts such as pharmacy import confirmations, daily health tips, and system alerts.

*   **Screen 4: Reports (Analytics)**
    *   A dashboard showing weekly adherence summaries.
    *   Include an overarching compliance percentage (e.g., "Taken" vs. "Missed").
    *   Provide a list-view log of dosage history. Ensure this data is architected so it can be exported (e.g., to PDF) for doctors.

*   **Screen 5: More (Settings & Extras)**
    *   Menu items for advanced settings, clinical tools, and bio-metric tracking modules.

**3. Complex Functional Workflows & Logic**

*   **The Smart Entry Wizard (Adding Medications)**
    *   Create a multi-step modal or dedicated flow for adding a new pill.
    *   It must include: text input with auto-complete/search simulation for the drug name, dose frequency pickers (e.g., daily, specific days), specific time selection, and a visual picker to customize the pill shape and color.
*   **Drug Interaction Engine**
    *   Implement logic (or mock logic) that runs when a user adds a new medication.
    *   It should cross-reference the new entry against the existing "Med Cabinet" state and display a clear warning/alert UI if contraindications (drug-to-drug or drug-to-food) are detected.
*   **Caregiver System ('Medfriend')**
    *   Design the system architecture and UI flows to support syncing with a secondary user.
    *   If a dose on the primary user's schedule passes its time-block and is not marked "Taken", trigger an event/notification meant to alert this secondary contact.
*   **Refill Reminders**
    *   Implement inventory tracking. When a user marks a pill as taken, subtract it from the total defined in the Med Cabinet.
    *   When the count hits a predefined low threshold, generate a visible alert/push notification reminder to refill.
*   **Bio-metric & Health Tracking**
    *   Include a module (perhaps accessed from the "More" tab) to log specific health metrics. Look to design forms for logging: Blood Pressure, Glucose levels, and Weight.
    *   Include a "Diary" feature for users to log symptoms with automatic timestamps.

**Execution Instructions:**
Begin by defining the global CSS variables/design tokens. Then, scaffold the layout with the bottom navigation. Proceed to implement the core "Pillbox" screen and its interactive medication cards before moving on to the complex logical flows (Entry Wizard, Interaction Warnings). Do not use placeholder data where possible; structure the frontend state to handle these features dynamically.
