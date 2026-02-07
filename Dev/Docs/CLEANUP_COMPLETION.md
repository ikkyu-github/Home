# Xcode Warning Cleanup Tracker

ใช้ไฟล์นี้เป็น checklist สำหรับ tracking การเคลียร์ warnings จาก Xcode (เน้นแก้ทีละหมวด เพื่อหลีกเลี่ยง regression)

- **Last reviewed:** 18 มกราคม 2569
- **Rule of thumb:** แก้ warnings โดย “ไม่เปลี่ยน runtime behavior” ถ้าเป็นไปได้

## Concurrency / MainActor

- [ ] ไล่ warnings เกี่ยวกับ `@MainActor` / `Sendable` / actor isolation แล้วจัดกลุ่มตามโมดูล
- [ ] ตรวจจุดที่ต้อง `await MainActor.run { ... }` หรือย้ายงาน UI กลับ main thread
- [ ] แก้ `Task {}` / closure captures ให้ปลอดภัย (เช่น `[weak self]`) โดยไม่ทำให้ logic เปลี่ยน
- [ ] ตรวจ `@preconcurrency` / legacy API bridges ว่าจำเป็นจริงหรือไม่
- [ ] เพิ่ม/ปรับ annotation เฉพาะจุด (เช่น `@MainActor` ที่ type หรือ method) แทนการครอบทั้งไฟล์ ถ้าเหมาะสม

## Deprecated APIs

- [ ] รวบรวม warnings “deprecated” ทั้งหมด (API, iOS version, SwiftUI) พร้อมเส้นทางแก้ไข
- [ ] แทนที่ API ที่ถูก deprecate ด้วยตัวใหม่แบบ compatibility-safe (เช่น `if #available`)
- [ ] ถ้าแก้ไม่ได้ทันที: เพิ่ม TODO ระบุเหตุผล + milestone ที่จะลบ workaround
- [ ] ตรวจว่ามี deprecations จาก dependencies / frameworks ภายใน (SafariLike*) หรือไม่

## Unused imports / variables

- [ ] ลบ unused `import` ที่ Xcode เตือน (โดยไม่ทำให้ implicit linking/objc bridging พัง)
- [ ] ลบ/rename unused locals/params หรือเปลี่ยนเป็น `_` ตาม style โปรเจกต์
- [ ] ตรวจ dead code paths ที่ถูกปิดด้วย `#if DEBUG` / feature flags
- [ ] ระวัง “unused but keeps side effects” (เช่น keep-alive tokens / observation hooks)

## SwiftUI State / Binding issues

- [ ] แก้ warnings เกี่ยวกับ `@State`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject` usage
- [ ] ตรวจ `Binding` ที่อาจหลุด lifecycle หรือถูกสร้างจาก value ชั่วคราว
- [ ] ตรวจการ mutate state ระหว่าง view update (เช่น “Publishing changes from within view updates…”) และย้ายไป `onAppear`/`task`/`onChange`
- [ ] ตรวจ identity issues (`.id`, `ForEach` key) ที่ทำให้ state reset หรือเกิด warning
- [ ] ตรวจ thread-safety: state updates ต้องเกิดบน main thread (หรือผ่าน `MainActor`)
