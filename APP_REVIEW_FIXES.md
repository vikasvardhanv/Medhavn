# Apple App Review Feedback Fixes

## Status: ✅ RESOLVED (Option B: Fresh Consent Prompt)

---

## Issue 1: Download Size & Consent ✅

**Original Problem:**
Users could tap "Skip Download" on first launch, but then when accessing the chat feature, the app would attempt to download the 320 MB model anyway without asking for consent again.

**Solution Implemented: Option B - Fresh Consent Prompt**

When a user opens chat without downloading the model, they see a fresh consent sheet with the same download disclosure. This allows users to:
1. Choose to download the AI model (showing 320 MB size + progress)
2. Continue without the model (using rule-based fallback mode)
3. Never be forced into a download

### Key Changes:

#### AppState.swift
- Removed `isDownloadSkipped` flag (no longer needed for Option B)
- `skipFirstLaunchSetup()` simply marks first launch as done

#### FloatingPillChatView.swift (Main Changes)
1. Added state variable:
```swift
@State private var showDownloadConsent = false    // Show consent sheet if model not ready
```

2. Updated `loadModel()` logic:
```swift
private func loadModel() async {
    // If model already warmed: load it
    if appState.isModelWarmedUp { ... return }
    
    // If model not ready AND no consent: show consent sheet
    if !appState.isDownloadConsentGiven {
        isLoadingModel = false
        showDownloadConsent = true  // Show the consent sheet
        return
    }
    
    // User has consented: start download
    isLoadingModel = true
    // ... download logic ...
}
```

3. Added consent sheet presentation:
```swift
.sheet(isPresented: $showDownloadConsent) {
    IntuioChatDownloadConsentSheetView(
        isPresented: $showDownloadConsent,
        onConsent: { appState.startModelDownloadWithConsent(); Task { await loadModel() } },
        onSkip: { modelReady = false; modelLoadFailed = false }
    )
}
```

4. Created `IntuioChatDownloadConsentSheetView`:
   - Shows same design as FirstLaunchSetupView
   - Discloses "approximately 320 MB" download size
   - Recommends Wi-Fi
   - Explains on-device processing
   - Offers "Download Now" or "Continue without AI model" options

### User Experience Flow:

```
First Launch
├─ Show FirstLaunchSetupView
├─ User has choice: "Download Now" or "Skip"
└─ If "Skip" → Setup marked done (won't show again)

Later: User Taps Chat (Pill Button)
├─ App checks if model is ready
├─ If not ready and no consent given
│  └─ Show IntuioChatDownloadConsentSheetView
├─ User can now choose:
│  ├─ "Download Now (~320 MB)" → Downloads with progress
│  └─ "Continue without AI model" → Uses fallback mode
└─ Chat works either way
```

### Compliance with App Review Guidelines:

✅ **Guideline 4.2.3(ii) - Minimum Functionality:**
- Download size disclosed: "approximately 320 MB"
- User is prompted at point of use (when opening chat)
- User has explicit choice: download or continue
- App is fully functional without download (fallback mode)
- No forced downloads ever occur

---

## Issue 2: Medical Citations & Sources ✅

**Status: Already Implemented** ✅

Your app already has comprehensive medical sources. No changes needed.

### Available Medical Sources:

**Drug Interactions:**
- DrugBank Open Data
- FDA Drug Interactions Labeling
- NIH DailyMed

**Health Metrics & Reference Ranges:**
- WHO BMI Classification
- NIH Blood Pressure Guidelines
- ADA Blood Glucose Standards
- CDC Vital Signs Reference Ranges
- MedlinePlus Lab Tests

**Medications:**
- MedlinePlus Drug Information
- Drugs.com
- PharmacyChecker.com

### Citation Access Points:
1. **Settings → "Medical Sources"** - Central hub for all sources
2. **Drug Interactions** - "View source details" links in interaction cards
3. **Health Metrics** - "View all sources" in Measurements view
4. **Throughout App** - Safety disclaimers and provider recommendations

---

## Files Modified:

| File | Changes |
|------|---------|
| `AppState.swift` | Removed `isDownloadSkipped` flag; restored simple skip logic |
| `FloatingPillChatView.swift` | Added `showDownloadConsent` state; Updated `loadModel()` to check consent; Added new consent sheet view |

---

## Testing Checklist Before Resubmission:

### First Launch Flow
- [ ] Launch app for first time → See FirstLaunchSetupView
- [ ] Verify download size shown: "Download size: approximately 320 MB"
- [ ] Tap "Skip — use app without AI assistant"
- [ ] Verify setup screen doesn't show again

### Chat After Skip
- [ ] Tap pill button (floating chat) → Opens chat
- [ ] Verify consent sheet appears (not an error)
- [ ] Consent sheet shows "Download size: approximately 320 MB"
- [ ] Can tap "Download Now" → Download starts with progress
- [ ] Or tap "Continue without AI model" → Chat uses fallback mode

### Chat After Consent
- [ ] Fresh install, tap "Download Now" on first launch
- [ ] Verify download shows progress and percentage
- [ ] Verify model loads successfully
- [ ] Chat works with full AI model (no fallback indicator)

### Medical Sources
- [ ] Open Settings → "Medical Sources"
- [ ] Verify all sources are clickable/accessible
- [ ] Tap through to DrugBank, FDA, NIH, WHO, etc.
- [ ] Check drug interaction detail screen sources
- [ ] Check health metrics detail screen sources

---

## App Review Submission Notes

When resubmitting, include in the Review Notes:

> **Issue 1 Fix (4.2.3(ii) - Minimum Functionality):**
> Fixed download consent flow. Users who skip the initial download still get a clear consent prompt when accessing the chat feature. The prompt discloses the download size (approximately 320 MB) and gives users explicit choice to download or use the app's fallback mode. No downloads occur without user consent.
>
> **Issue 2 Fix (1.4.1 - Safety/Medical Info):**
> Comprehensive medical citations are implemented throughout the app:
> - Settings → "Medical Sources" provides central hub
> - Drug interactions cite DrugBank, FDA, NIH DailyMed
> - Health metrics cite WHO, NIH, ADA, CDC, MedlinePlus
> - All medical information includes safety disclaimers
> - Sources are easily accessible with clickable links

---

## Key Improvement: Option B vs Option A

**Option A (Fallback Mode):**
- User skips → Can't download later → Forces fallback mode
- Less flexible; changes app behavior based on initial choice

**Option B (Fresh Consent) ✅ - Selected**
- User skips → Can still opt-in when trying the feature
- More flexible; respects user choice without limiting options
- Better UX; gives second chance to try AI features
- Still compliant with App Review guidelines
