# Test Plan: Crash-safe Journal + Deterministic Replay + 2-View Budget

> Date: 21 ม.ค. 2569

## Goals
- **A) SessionJournal crash-safe**: อ่าน log ได้แม้ไฟล์เสียท้าย/CRC เสีย และต้อง truncate bad tail แบบ crash-safe
- **B) Deterministic replay**: events ชุดเดียวกันต้อง replay ได้ผลลัพธ์เหมือนเดิมเสมอ และ out-of-order ต้องให้ผลเหมือนกันหลัง deterministic sort
- **C) 2-view budget enforcement**: TabRegistry ต้อง enforce `BrowserPolicy.maxConcurrentViews == 2` (activate เกิน 2 ต้อง evict LRU)

## Scope / Non-goals
- ไม่ทดสอบ WebKit networking จริง
- ไม่ทดสอบ UI activation paths (ทดสอบเฉพาะ CoreKit registry policy)

## Test Matrix
### A) SessionJournal crash-safe (BrowserCoreTests)
- [A1] Append 10 events แล้ว `readAllEvents()` คืนครบ 10
- [A2] Truncate bytes ท้ายไฟล์ (simulate crash mid-write) แล้ว `readAllEvents()`:
  - คืนเฉพาะ record ที่สมบูรณ์
  - truncate bad tail (ขนาดไฟล์ลดลง)
- [A3] CRC เสีย (flip byte) แล้ว `readAllEvents()`:
  - ไม่ crash
  - ตัด tail และผลลัพธ์คงเหลือเฉพาะ record ที่สมบูรณ์

### B) Deterministic replay (BrowserCoreTests)
- [B1] Replay events ชุดเดียวกัน 2 รอบ -> `SessionState` เท่ากันทุก field (เทียบด้วย JSONEncoder `.sortedKeys`)
- [B2] Out-of-order inputs หลายแบบ -> replay ภายใต้ policy `.sortByDeterministicKey` ต้องได้ state เดิมเสมอ

### C) 2-view budget enforcement (SafariLikeCoreKitTests)
- [C1] Activate tab A,B -> `activeWebViewsCount == 2`
- [C2] Activate tab C -> ต้อง deactivate LRU (A หรือ B ตาม policy) และ `activeWebViewsCount` ยัง == 2

## How to run (recommended)
- BrowserCore focused:
  - List simulator IDs:
    - `xcodebuild -project webOS.xcodeproj -scheme BrowserCoreTests -showdestinations`
  - Run (replace `<SIMULATOR_ID>`):
    - `xcodebuild test -project webOS.xcodeproj -scheme BrowserCoreTests -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' -only-testing:BrowserCoreTests/SessionJournalCrashSafeTests`
    - `xcodebuild test -project webOS.xcodeproj -scheme BrowserCoreTests -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' -only-testing:BrowserCoreTests/SessionReplayDeterminismTests`
- CoreKit focused:
  - List simulator IDs:
    - `xcodebuild -project webOS.xcodeproj -scheme SafariLikeCoreKitTests -showdestinations`
  - Run (replace `<SIMULATOR_ID>`):
    - `xcodebuild test -project webOS.xcodeproj -scheme SafariLikeCoreKitTests -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' -only-testing:SafariLikeCoreKitTests/TabRegistryBudgetTests`
