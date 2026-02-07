import SafariLikeCoreKit
/// SafariLikeKit Public API Facade
///
/// จุดเริ่มต้นอย่างเป็นทางการสำหรับการใช้งาน SafariLikeKit จากภายนอก
/// แอปควรโต้ตอบกับ SafariLikeKit ผ่าน entrypoints ที่ระบุไว้ที่นี่เท่านั้น
/// และไม่ผูกกับ ViewModel หรือ runtime ภายในโดยตรง.
///
/// # Entry Points หลัก
/// - การตั้งค่า: ``SafariLikeConfiguration``
/// - โรงงานสร้าง session: ``SafariLikeFactory``
/// - SwiftUI root view: `SafariLikeBrowserView` (from SafariLikeUIKit)
/// - UIKit integration host: `SafariLikeUIKitHost` (from SafariLikeUIKit)
/// - โมเดลข้อมูล: ``BrowserBookmark``, ``BrowserHistoryItem``, ``BrowserReadingListItem``
///
/// # ลำดับการใช้งานที่แนะนำ
/// 1. สร้างค่าเริ่มต้นด้วย ``SafariLikeConfiguration`` (หรือใช้ `.default`).
/// 2. ในแต่ละ scene/หน้าต่าง เรียก ``SafariLikeFactory/makeSceneSession(sceneID:configuration:)``
///    เพื่อสร้าง `BrowserSceneSession` ภายใน.
/// 3. ใน SwiftUI scene ใช้ `SafariLikeBrowserView` จากโมดูล SafariLikeUIKit เป็น root view ของเบราว์เซอร์.
/// 4. ใน UIKit app ใช้ `SafariLikeUIKitHost` จากโมดูล SafariLikeUIKit เพื่อสร้าง `UIViewController` ที่โฮสต์ SafariLikeBrowserView.
///
/// # เสถียรภาพของ API
/// ชนิดต่อไปนี้ถือเป็นส่วนหนึ่งของ Public API ที่ตั้งใจให้เสถียร:
/// - ``SafariLikeConfiguration``
/// - ``SafariLikeFactory``
/// - ``BrowserBookmark``
/// - ``BrowserHistoryItem``
/// - ``BrowserReadingListItem``
///
/// ส่วนชนิดภายในเช่น `SplitBrowserViewModel`, `BrowserChromeState`, `AppTabManager`,
/// `TabWebStore`, `TabRegistry`, `AppMenuCommands`, `AppWindowActions` และ runtime อื่น ๆ 
/// *ไม่* ถือเป็น Public API และอาจเปลี่ยนแปลงได้ตลอดเวลา โดยไม่ต้องแจ้งเตือน
///
/// # Namespaced Aliases
/// เพื่อความสะดวก คุณสามารถเข้าถึง entrypoints หลักผ่าน namespace นี้ได้เช่นกัน:
/// - ``SafariLikeKitPublicAPI/Configuration``
/// - ``SafariLikeKitPublicAPI/Factory``
public enum SafariLikeKitPublicAPI {
	/// ตัวตั้งค่าหลักของ SafariLikeKit ที่ใช้กำหนดพฤติกรรมของเบราว์เซอร์.
	///
	/// เป็น typealias ตรงไปยัง ``SafariLikeConfiguration`` เพื่อให้อ่านง่ายในบริบทของ facade.
	public typealias Configuration = SafariLikeConfiguration
	/// โรงงานสำหรับสร้าง `BrowserSceneSession` ภายใน.
	///
	/// เป็น typealias ตรงไปยัง ``SafariLikeFactory`` ซึ่งให้เมทอด
	/// ``SafariLikeFactory/makeSceneSession(sceneID:configuration:)``.
	public typealias Factory = SafariLikeFactory
}
