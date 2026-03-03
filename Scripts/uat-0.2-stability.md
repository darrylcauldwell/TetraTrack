# UAT Script: 0.2 Stability Milestone

Test on a physical device via TestFlight after CI deploys the build.
Mark each check pass/fail. If a check fails, note the issue number for regression.

---

## Prerequisites

- [ ] CI pipeline passed on push to main
- [ ] TestFlight build available and installed on test device(s)
- [ ] For #37: Two physical iPhones with different iCloud accounts, both on TestFlight

---

## #39 — Language selector layout

**Screen:** Settings > Language

1. [ ] Open Settings, tap the language selector
2. [ ] All language names display in full — no truncation or ellipsis
3. [ ] Layout is readable (text not squeezed into a narrow column)
4. [ ] Select a different language — app language changes as expected
5. [ ] (If possible) Test on smallest device / narrowest Dynamic Type — still readable

---

## #44 — Weekly focus layout (rows not columns)

**Screen:** Skills Training (any discipline)

1. [ ] Open a discipline's Skills Training section
2. [ ] "This Week's Focus" section shows skills in horizontal rows (not a 3-column grid)
3. [ ] Each row is tappable and navigates to the correct drill
4. [ ] Rotate device to landscape — layout still works (no overlap or truncation)

---

## #43 — Watch status cards across disciplines

**Prerequisite:** Apple Watch paired and TetraTrack Watch app installed

**Riding:**
1. [ ] Start a riding session on iPhone — Watch shows status card with live metrics
2. [ ] Card updates in real-time (distance, duration, heart rate)

**Running:**
3. [ ] Start a running session on iPhone — Watch shows status card
4. [ ] Card updates in real-time

**Swimming:**
5. [ ] Open the swimming section — Watch status card is visible (this was previously missing)
6. [ ] Start a swimming session — Watch card updates during session

**Shooting:**
7. [ ] Open the shooting section — status card appears at the session level (not buried inside drills)
8. [ ] Cards appear in consistent order across all disciplines

---

## #41 — Gait detection accuracy

**Prerequisite:** Horse or simulated ride (can test with GPS trace or real ride)

1. [ ] Start a riding session and walk the horse (0-7 km/h)
   - [ ] Gait display shows "Walk" — NOT canter or gallop
2. [ ] Trot the horse (7-20 km/h)
   - [ ] Gait display shows "Trot" — NOT gallop
3. [ ] Canter the horse (20-35 km/h)
   - [ ] Gait display shows "Canter"
4. [ ] Check the ride summary after ending the session
   - [ ] No spurious single-sample spikes to higher gaits (e.g. "gallop" during walk)
   - [ ] Gait breakdown percentages look reasonable for the ride

---

## #45 — Coaching insights from session history

**Screen:** Skills Training > any discipline > coaching insights

**With session history:**
1. [ ] Complete at least one drill/session in a discipline
2. [ ] Return to the coaching insights section
3. [ ] Insights reference actual data (e.g. "your balance improved", specific metrics)
4. [ ] Insights are NOT generic/placeholder text

**Without session history (fresh discipline):**
5. [ ] Open a discipline with no completed sessions
6. [ ] Verify an appropriate empty state is shown (not broken UI or stale data)

**After new session:**
7. [ ] Complete a new session/drill
8. [ ] Return to insights — they should reflect the new data

---

## #37 — Family sharing (CloudKit zone-level shares)

**Prerequisite:** Two physical iPhones (Device A + Device B) on different iCloud accounts, both running the TestFlight build.

**Share creation (Device A):**
1. [ ] Open Family Sharing settings on Device A
2. [ ] Create a new sharing invitation
3. [ ] Share link generates successfully (not nil / no error)
4. [ ] Send the link to Device B (via Messages, AirDrop, etc.)

**Share acceptance (Device B):**
5. [ ] Tap the share link on Device B
6. [ ] "Connected!" confirmation appears
7. [ ] Device B shows Device A's name in the family contacts list

**Live tracking visibility:**
8. [ ] Device A starts a riding session (or any GPS-tracked session)
9. [ ] Device B opens "Shared With Me" / family location view
10. [ ] Device B sees Device A's live location updating in real-time

**Bidirectional test:**
11. [ ] Repeat steps 8-10 with roles reversed (Device B rides, Device A watches)

**Console log check:**
12. [ ] No "CloudKit environment mismatch" errors in device logs
13. [ ] Logs show "Zone-level ShareConnection created successfully" (not "Record-level")

---

## Final checks

- [ ] All tests above pass
- [ ] No crashes encountered during testing
- [ ] No unexpected console errors
- [ ] Close each issue on GitHub after confirming its acceptance criteria are met
