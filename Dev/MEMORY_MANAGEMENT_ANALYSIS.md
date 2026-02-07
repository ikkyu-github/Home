# BrowserChromeState Memory Management Refactoring

## ปัญหาเดิม

### 1. **vm deallocated unexpectedly**
**สาเหตุ:** 
```swift
private weak var vm: SplitBrowserViewModel?
```
- BrowserChromeState ถือ weak reference เท่านั้น
- ไม่มี guarantee ว่า VM จะยังมีอยู่ระหว่างการทำงาน
- ถ้า someone deallocates VM แต่ Chrome still active → crash

**วิธีแก้:**
- VM ต้องเป็น strong owner ของ Chrome (ไม่ใช่ในทางกลับ)
- Chrome ถือ weak reference ต่อ VM ได้
- ลบ TODO comment และอธิบายความเป็นมาอย่างชัดเจน

---

### 2. **activeStore is nil ทั้งที่ activeTabID มีค่า**
**สาเหตุ:**
```swift
assertionFailure("activeStore is nil for activeTabID: \(tabID)")
```
- Race condition ในการ switch tab
- ไม่ได้ใช้ logger - debug บลาๆ
- ใช้ assertionFailure ซึ่งจะ crash in debug แต่ไม่ใน release

**วิธีแก้:**
- เปลี่ยนเป็น logger.error() พร้อม explanation
- ข้ามการทำงาน gracefully (return early)
- อธิบายว่าเหตุการณ์นี้ hints at TabManager race condition

---

### 3. **Multiple weak references ใน onPageDidFinish**
**สาเหตุ:**
```swift
store.onPageDidFinish = { [weak self, weak store] (url: URL?, title: String) in
    guard let self, let store, let vm = self.vm else {
        return
    }
    // ...
}
```
- `[weak store]` ไม่จำเป็น - callback จะไม่ถูกเรียก if store deallocated
- `self.vm` lookup ทีหลัง = nested weak reference
- Guard statement ยาวจึง confusing

**วิธีแก้:**
- ลบ `weak store` - store guaranteed alive
- ใช้ `self` -> `vm` lookup หลังจาก guard self
- Split logic: guard tabID ก่อน, bind vm ที่มีความปลอดภัย

---

## Ownership Model (ตั้งแต่เดี๋ยว)

```
┌─────────────────────────────────────────────┐
│ SplitBrowserViewModel (Strong)              │
│                                              │
│  ├─ TabManager (owns stores)                │
│  │   └─ TabWebStore (owns WebView)          │
│  │                                          │
│  └─ BrowserChromeState (owns downloads)    │
│      └─ DownloadStore                       │
│      └─ TabThumbnailStore (ref to Core)     │
│                                              │
│  // Circular reference PREVENTED:           │
│  Chrome holds WEAK ref to VM                │
│  VM holds STRONG ref to Chrome              │
└─────────────────────────────────────────────┘
```

**Key Principle:**
```
View Models are OWNERS, Views/Chrome are OBSERVERS
```

---

## Refactored: hookActiveTab()

### Before (Problematic)
```swift
func hookActiveTab() {
    guard let vm else {
        // TODO: STABILITY - vm deallocated unexpectedly
        return
    }
    
    guard let store = vm.activeStore else {
        assertionFailure("activeStore is nil for activeTabID: \(tabID)")
        return
    }
    
    store.onPageDidFinish = { [weak self, weak store] (url: URL?, title: String) in
        guard let self, let store, let vm = self.vm else {
            return  // Confusing - which was deallocated?
        }
        // ...
    }
}
```

### After (Clear & Safe)
```swift
func hookActiveTab() {
    // 1. Check VM is alive
    guard let vm else {
        // VM deallocated - normal cleanup, not error
        return
    }
    
    // 2. Check activeStore exists
    guard let store = vm.activeStore else {
        // Race condition - tabID exists but store doesn't
        Self.logger.error("activeStore is nil despite activeTabID being set")
        return
    }
    
    // 3. Setup side effect with ONLY necessary captures
    store.onPageDidFinish = { [weak self] (url: URL?, title: String) in
        // Guard Chrome first (outer owner)
        guard let self else {
            return  // Chrome deallocated
        }
        
        // Guard VM second (still possible to deallocate)
        guard let vm = self.vm else {
            return  // VM deallocated
        }
        
        // store is guaranteed alive here (callback only called while store exists)
        let webView: WKWebView = store.webView
        
        // Execute side effect...
    }
}
```

---

## Key Changes Explained

### 1. **Removed `[weak store]`**
```swift
// ❌ Before
store.onPageDidFinish = { [weak self, weak store] (url: URL?, title: String) in
    guard let self, let store, let vm = self.vm else {

// ✅ After
store.onPageDidFinish = { [weak self] (url: URL?, title: String) in
    guard let self else {
        return
    }
    guard let vm = self.vm else {
        return
    }
```

**Why?**
- `store.onPageDidFinish` closure is **only stored on `store`**
- Closure is **only invoked while `store` is alive**
- When `store` is deallocated, closure is released (no callback)
- Therefore: `store` can NEVER be nil inside the closure
- Using `[weak store]` adds impossible guard, increases complexity

---

### 2. **Replaced assertionFailure with logger**
```swift
// ❌ Before
guard let store = vm.activeStore else {
    assertionFailure("activeStore is nil for activeTabID: \(tabID)")
    return
}

// ✅ After
guard let store = vm.activeStore else {
    Self.logger.error("activeStore is nil despite activeTabID: \(tabID) being set. Skipping chrome binding.")
    return
}
```

**Why?**
- assertionFailure = crash in debug, silent in release
- logger = works everywhere + searchable in crash logs
- Explains it's a TabManager race condition, not our bug

---

### 3. **Clearer ownership documentation**
```swift
/// **Ownership Model:**
/// - SplitBrowserViewModel (strong) owns TabManager
/// - TabManager (strong) owns activeStore
/// - BrowserChromeState (weak) references VM
/// 
/// This prevents circular reference: VM → Chrome → VM
```

**Why?**
- Prevents future devs from "fixing" by making Chrome strong owner
- Explains why guard let vm check is okay (Chrome is disposable)
- Documents the circular reference prevention strategy

---

## Lifecycle Safety

### Safe Scenarios
1. **VM deallocated while Chrome is active**
   - Chrome's weak ref becomes nil
   - hookActiveTab returns early
   - No crash ✓

2. **Store deallocated while onPageDidFinish is setup**
   - Callback is immediately released
   - Never invoked ✓

3. **Page finishes loading while Chrome deallocates**
   - guard let self fails
   - Thumbnail capture skipped ✓

4. **Tab deleted between activeTabID check and activeStore access**
   - Caught by `guard let store = vm.activeStore`
   - Logged, function returns ✓

---

## Guidelines for Similar Code

When writing closures captured by owned objects:

```swift
// ✅ Correct: Captures only what's necessary
store.callback = { [weak self] value in
    guard let self else { return }
    // store is guaranteed alive (owns this closure)
    process(value)
}

// ❌ Wrong: Unnecessary weak reference
store.callback = { [weak self, weak store] value in
    guard let self, let store else { return }
    // store is ALWAYS alive here - no need for guard
    process(value)
}

// ❌ Wrong: Circular reference
viewModel.callback = { [strong self] value in
    // Don't capture self strongly in objects you own!
    self.doSomething()
}
```

---

## Testing Recommendations

### Race Condition Detection
```swift
// Test 1: Delete tab while page is loading
let tabID = vm.newTab()
vm.selectTab(tabID)
vm.closeTab(tabID)  // Race: Chrome might still try to bind

// Test 2: Switch modes rapidly
for i in 0..<100 {
    vm.isPrivateMode.toggle()
    // activeStore might be nil due to registry switch
}

// Test 3: Deallocate VM while Chrome bound
weak var weakVM = vm
vm = nil
// Chrome should gracefully handle nil vm
```

---

## Summary

| Issue | Before | After |
|-------|--------|-------|
| vm deallocated | TODO comment | Documented graceful handling |
| activeStore nil | assertionFailure | logger.error + early return |
| Multiple weak refs | [weak self, weak store] | Only [weak self] needed |
| Ownership clarity | Unclear | Documented in docstring |
| Side effect safety | Guard chain | Separate guards with clear intent |

**Bottom line:** Remove weak references where ownership guarantees they'll never be nil. Use logger instead of assertions. Document ownership relationships explicitly.
