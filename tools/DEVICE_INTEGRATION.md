# Pill dispenser integration (Betife 28-day Bluetooth pill box)

Status: research only. No device code exists yet, and none should be written before the unit is in hand.

## What we know (from public listings, not from the device)

- Product: Betife Automatic Pill Dispenser, "28-Day Smart Bluetooth Pill Box" (Amazon ASIN B0GDZYSK9B).
- Link to the phone: **Bluetooth only**. No Wi-Fi, cellular or hub is mentioned anywhere.
- Companion app: **PillCalendar** (App Store id1592652731). It sets up to 6 alarms a day, keeps its own dose history, and shows statistics.
- Other features: light and sound reminders, six buttons on the box, key lock plus fingerprint reader.
- No public API or developer documentation was found for PillCalendar or the box.
- One review says Bluetooth models only alert a phone that is in range. A remote caregiver sees nothing.

## What we do not know yet

1. Whether the box moves pills by motor, or only alarms and unlocks a lid.
2. Whether it reports when a compartment is opened, which is the only proof a dose was taken.
3. The Bluetooth protocol: services, characteristics, message format, pairing and encryption.
4. Whether it allows two phones at once. Many Bluetooth boxes accept one connection, so PillCalendar and Medhavn may not work together.

## What this means for "control it from our app"

- Control happens over **Bluetooth Low Energy, directly from the phone**. A server cannot reach the box.
- The phone must be near the box. Alerts to family members still work, but only after the phone has read the event and sent it to the backend.
- Without a published protocol, integration means reverse engineering the Bluetooth messages of a device we own. Use the REA method. Tag every finding OBSERVED, INFERRED or UNKNOWN.

## Plan, once the unit arrives

1. **Hardware check.** Open the box. Confirm points 1 and 2 above. If the box cannot report a dose, stop here. The integration is then reminders only, and a different device is the better choice.
2. **Ask the vendor.** Email Betife for a protocol document or SDK. This is cheaper than reverse engineering.
3. **Enumerate.** Install Nordic nRF Connect for Mobile (free). Connect to the box. Record every service and characteristic and which ones notify.
4. **Capture.** Install Apple's PacketLogger (Additional Tools for Xcode) and the Bluetooth logging profile on an iPhone. Use PillCalendar to: sync the clock, set an alarm, open a compartment, and delete an alarm. Capture each action separately and note the time.
5. **Decode.** Match each action to the bytes written or notified. Replay one write from nRF Connect to confirm. Rule of two: two failed readings of a message means UNKNOWN.
6. **Decide.** If the protocol is encrypted or bonded to the vendor app, stop and choose another device.

## Target design (build after step 5)

- `PillDevice` protocol: connect, set schedule, and an event stream of `opened`, `taken`, `missed`, `battery`.
- A Bluetooth implementation for this box behind that protocol. CoreBluetooth with the `bluetooth-central` background mode and state restoration.
- A `taken` event calls the existing `markDose`. The existing sync, missed-dose alerts and sharing then work unchanged.
- A device-event table in the database only if events must be audited. Not needed for v1.
- iOS apps cannot keep a Bluetooth link alive forever in the background. Test the box with the app closed before promising automatic dose capture.

## If Bluetooth-only is not enough

Look for a Wi-Fi or cellular dispenser with a documented cloud API. Then the backend talks to the device vendor directly, and a family member can be told about a missed dose even when the phone is off.
