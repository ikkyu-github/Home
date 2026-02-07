# SafariLikeCoreKit

> Core browser runtime for Safari‑like apps. UI‑agnostic, WebKit‑centric, main‑actor.

## 1. CoreKit คืออะไร / ไม่ใช่อะไร

**CoreKit คือ**:
- แหล่งรวม runtime logic ระดับ “engine” ของ browser แท็บเดียวและ registry ของหลายแท็บ
- จุดเดียวที่รู้จริงเรื่อง `WKWebView` lifecycle, process recovery, content blocking, และ tab state model
- Framework ที่ตั้งใจให้ **UI ทุกแบบใช้ร่วมกันได้** (SwiftUI, UIKit, AppKit, ฯลฯ) โดยผูกกับแค่ Foundation / WebKit (+ frameworks system ที่ไม่ใช่ UI)

**CoreKit ไม่ใช่**:
- ไม่ใช่ UI framework → ห้ามมี `UIKit` / `SwiftUI` ใน target นี้ (adapter ไปอยู่ที่ SafariLikeKit หรือ layer อื่น)
- ไม่ใช่ที่เก็บ global app state/UI chrome state (เช่น sidebar visibility, current scene ฯลฯ)
- ไม่ใช่ที่ให้คุณจัดการ memory ของ `WKWebView` เองแบบ manual นอกเหนือจาก API ที่มีให้

สั้น ๆ: **คิดว่า CoreKit = “tab engine + tab registry + content blocking” ที่ไม่รู้จัก UI**.

---

## 2. Lifecycle ของ Tab / WebStore

อ็อบเจ็กต์หลักฝั่ง runtime:
- `TabWebStore`  – engine ของแท็บเดียว (ห่อ `WKWebView` + state)
- `TabRegistry`  – จัดการ pool ของ `TabWebStore` หลายตัวแบบ Safari (LRU + eviction)

### 2.1 TabWebStore

สถานะหลัก ๆ:
- สร้างด้วย `TabWebStore(role:configuration:defaultHomeURLString:searchEngineURL:contentBlockerManager:)`
- เริ่มทำงานผ่าน `activate()` → สมัคร observer ต่าง ๆ, พร้อมใช้งาน
- โหลดหน้าเว็บผ่าน:
  - `load(_ urlString: String, force: Bool = false)`
  - `loadSearch(query: String)`
- จบอายุด้วย `invalidate()`:
  - ยกเลิก observers/task ทั้งหมด
  - detach delegates, หยุด web loading, invalidate webView core

หลัง `invalidate()`:
- ห้ามเรียก API ที่เปลี่ยน state อีก (guard อยู่แล้ว แต่ห้ามพึ่งพา behavior นั้นใน design)
- ให้ถือว่า instance นั้น “ตายแล้ว” → อย่าเก็บ reference ไปใช้ภายหลัง

### 2.2 TabRegistry

- สร้างด้วย config ชัดเจน (data store, max alive webviews, default home URL, search engine URL, content blocking, configuration factory)
- สร้าง/คืนค่า runtime tab ผ่าน:
  - `store(for: UUID, role: TabWebStore.Role = .primary) -> TabWebStore`
- ใช้สำหรับ tab ที่ยังมี runtime อยู่ผ่าน:
  - `existingStore(for:)` – คืนค่า `TabWebStore?` ถ้ายัง alive
  - `aliveTabIDs: [UUID]` – รายชื่อแท็บที่มี runtime อยู่ตอนนี้
- Lifecycle ของ tab แต่ละตัว: ถูกสร้าง, ถูกใช้, จากนั้นถูก `invalidate()` ผ่าน LRU eviction หรือ explicit remove

---

## 3. กติกาการอ่าน state (snapshot / observe เท่านั้น)

Core rule: **โค้ดภายนอกห้ามแตะ internal state ตรง ๆ ให้ใช้เฉพาะ snapshot & observer API**.

### 3.1 Snapshot state

- อ่านสถานะปัจจุบันของ tab ผ่าน:
  - `TabWebStore.state: TabWebStoreState` (ใน Public layer: `TabState`)
- `TabWebStoreState` เป็น `struct` ที่ `Sendable` + `Equatable`:
  - ปลอดภัยที่จะ pass ระหว่าง thread / actor
  - การแก้ค่าบน struct **ไม่ส่งผลกลับเข้า CoreKit**

ข้อควรจำ:
- Snapshot = รูปถ่าย ณ เวลาหนึ่ง ไม่ใช่ live view
- ถ้าต้องการอัปเดตข้อมูลใน UI ต่อเนื่อง → ใช้ observer แทน polling ด้วยตัวเอง

### 3.2 Observe state

- ใช้ observer API:
  - `observeState(_ handler: @escaping @MainActor (TabWebStoreState) -> Void) -> UUID`
  - `removeStateObserver(_ id: UUID)`
- ใน Public layer (`TabEngine`): method เหมือนกันแต่ผูกผ่าน protocol
- Handler ถูกเรียกบน main actor เสมอ

สิ่งที่ห้ามทำ:
- ห้ามเก็บ reference ไปยัง `TabWebStoreState` แล้วคิดว่ามันจะ “live sync” — ทุกครั้งที่ต้องใช้ค่าปัจจุบัน ให้ใช้ค่าที่ส่งมาล่าสุดจาก observer หรือเรียก `state` ใหม่

---

## 4. สิ่งที่ห้ามทำ (Do / Don’t)

### 4.1 WebView / lifecycle

**ห้าม**:
- ห้ามเก็บ reference `WKWebView` ที่อยู่นอก `TabWebStore` / `WebViewHandle`
- ห้ามตั้งค่า delegate ของ `WKWebView` เอง (navigation/ui/script) – CoreKit เป็นเจ้าของ delegate ทั้งหมด
- ห้ามเรียก method ใด ๆ บน `WKWebView` โดยตรงจาก code ภายนอก
- ห้ามพยายามจัดการ process recovery เอง (เช่น reload-loop, terminate detection) – มี logic ใน CoreKit อยู่แล้ว

**ให้ทำ**:
- ใช้ `TabWebStore.webViewHandle` สำหรับ interaction พื้นฐานที่ CoreKit เปิดไว้เท่านั้น:
  - `load(url:)`, `reload()`, `stopLoading()`
  - อ่าน `url`, `configuration`, `customUserAgent`, delegates ที่เปิดให้ set
  - ใช้ `withUserContentController(_:)`, `evaluateJavaScript(_:)`
- ถ้าต้องการ behavior ใหม่ที่แตะ `WKWebView` โดยตรง → ใส่ไว้ใน CoreKit (หรือ adapter ที่ CoreKit เป็นคนเรียก) แทนการเชื่อมตรงจาก UI

### 4.2 State / internal flags

**ห้าม**:
- ห้ามอ่าน/เขียน property ภายใน `TabWebStore` ที่ไม่ใช่ public API เช่น `pageTitle`, `isLoading`, `canGoBack`, ฯลฯ (พวกนี้ถูก wrap ใน `state` แล้ว)
- ห้ามเรียก `internal` helpers (เช่น `updatePageTitle`, `performLoadResolvedURL`, `invalidateWebViewCore`, ฯลฯ) นอก CoreKit เอง
- ห้าม mutate lifecycle flags เช่น `isInvalidated` โดยตรง (guard ภายในจัดการเอง)

**ให้ทำ**:
- อ่านทุกอย่างผ่าน `state` / observer เท่านั้น
- ควบคุม behavior ผ่าน public API ที่เตรียมไว้ (load, activate, invalidate, search, etc.)

### 4.3 Color / UI mapping

- `TabGroupColor` ใน CoreKit เป็น enum semantic เท่านั้น
- Mapping ไปเป็น `UIColor` / `SwiftUI.Color` ต้องทำใน layer UI (เช่น extension ใน SafariLikeKit)

---

## 5. Threading rule

เป้าหมายคือให้ชัดเจนว่า “อันไหน main actor, อันไหน cross‑thread ได้”: 

### 5.1 Main‑actor isolated types (stateful engine)

ต้องเรียกจาก main actor เสมอ (หรือผ่าน `@MainActor` call):
- `TabWebStore` ทั้งคลาส (รวม extensions ที่แตะ WebKit)
- `TabRegistry`
- `ContentBlockerManager`
- `WebViewConfigurationFactory`
- `WebViewHandle`
- `ChromePolicy` (แม้จะไม่ผูก UIKit แล้ว แต่ยังเป็น config ด้าน UI chrome)
- Public protocols ที่ผูกกับ runtime เหล่านี้:
  - `TabEngine`
  - `TabLifecycle`
  - `BrowserEngine`

สรุปง่าย ๆ: **ถ้าเป็น “engine ที่แตะ WebKit / lifecycle / content blocking” ให้ถือว่า main‑actor เสมอ**.

### 5.2 Pure / Sendable models

ใช้งานข้าม thread / actor ได้ตามสะดวก (ค่าคงตัว / struct):
- `TabWebStoreState` (`TabState` ใน Public)
- `TabModel`
- `CompanionItem` และโมเดลอื่นที่ conform `Sendable` และไม่มี reference ไปยัง object state

### 5.3 Practical rules (อีก 6 เดือนเปิดมาไม่ด่าตัวเอง)

- ถ้าฟังก์ชันของคุณ **แตะ WebKit, จัดการ lifecycle, แก้ state ภายใน** → ใส่ไว้ใต้ `@MainActor` ใน CoreKit
- ถ้าฟังก์ชันของคุณเป็นแค่ **คำนวณค่า / แปลงโมเดล** → อย่าใส่ `@MainActor` และพยายามทำให้ `Sendable`
- เวลาเพิ่ม public API ใหม่:
  1. ตัดสินใจก่อนว่าเป็น engine (main‑actor) หรือ pure model (Sendable)
  2. เขียน comment ให้ชัดว่า "Threading: ต้องเรียกจากไหน" แบบที่ทำในไฟล์ runtime ตัวอื่น
- เวลาอยากแตะ UIKit/SwiftUI ให้ถามตัวเองก่อน: 
  - “นี่ควรอยู่ใน SafariLikeKit หรือใน CoreKit?” → ถ้าเกี่ยวกับ view, trait, สี, layout → ไปที่ SafariLikeKit/UIButton/SwiftUI view

---

ถ้าคุณ (ตัวคุณในอนาคต) มาเปลี่ยน CoreKit:
- ดู public API ใน `Public/` ก่อนเสมอ
- ถ้าจะ expose ของใหม่ ให้คิดก่อนว่ากำลังหลุด implementation detail ออกไปหรือเปล่า
- ถ้าเริ่มคิดว่า “เดี๋ยวไปดึง webView มาแล้วทำ X เลย” ให้หยุด แล้วกลับมาอ่าน section 4 อีกรอบ 🙂
