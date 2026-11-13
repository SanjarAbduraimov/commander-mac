# Phase 2 Spec: Fayl operatsiyalari va transferlar (File Operations & Advanced Transfers)

Sana: 2026-11-14  
Holat: **Taklif (Ko'rib chiqish uchun)**  
Muallif: Antigravity  
Tegishli fayllar:
- `Packages/CommanderKit/Sources/CommanderCore/`
- `Packages/CommanderKit/Sources/CommanderFileSystem/`
- `Packages/CommanderKit/Sources/CommanderController/`
- `App/`
- `docs/brainstorm/2026-10-21-commander-decisions.md`

---

## 1. Maqsad va umumiy talablar

Total Commander uslubidagi professional darajadagi fayl operatsiyalari tizimini yaratish:
1. **Background Transfer Queue (Amallar navbati)**: F5 (Copy) va F6 (Move) amallarini navbatga qo'yish, tartiblash, nazorat qilish.
2. **Smart Concurrency (Aqlli oqim boshqaruvi)**: Bir xil disk/volume ichida ketma-ket (sequential), turli disklarda esa parallel bajarish.
3. **APFS Clone optimizatsiyasi**: Bir xil APFS drayv ichida nusxalashda macOS `clonefile` yordamida bir lahzada (instant) va disk joyini sarflamasdan nusxalash.
4. **Pause / Resume va Cancel**: Har qanday transferni to'xtatib turish, davom ettirish, qisman ko'chirilgan fayllarni davom ettirish (resume stream).
5. **Kengaytirilgan Konflikt Dialogi (Advanced Conflict Resolution)**: Fayllarni yonma-yon solishtirish (baytlar, sana farqi, media thumbnail), `Overwrite if older`, `Resume`, `Auto-rename`, `Skip all`.
6. **Xatolarni xavfsiz boshqarish (Fault Tolerance)**: Ruxsatsiz yoki band fayllarda `Retry / Skip / Abort`, jarayon oxirida xatoliklar hisoboti.
7. **Undo (`⌘Z`) va Redo (`⇧⌘Z`) tizimi**: Rename, Move, Copy (yangi nusxalarni Trash'ga yuborish) va Trash amallarini xavfsiz orqaga qaytarish.

---

## 2. Arxitektura va Modellar

### 2.1. Core qatlami (`CommanderCore`)

`CommanderCore` sof Swift moduli bo'lib, UI'ga bog'liq emas.

#### A. Transfer Modellari (`TransferJob.swift`)
```swift
public enum TransferKind: String, Codable, Sendable {
    case copy
    case move
}

public enum JobState: Equatable, Sendable {
    case queued
    case running(progress: TransferProgress)
    case paused
    case resolvingConflict(ConflictDetails)
    case completed
    case failed(String)
    case cancelled
}

public struct TransferProgress: Equatable, Sendable {
    public let bytesTransferred: Int64
    public let totalBytes: Int64
    public let filesTransferred: Int
    public let totalFiles: Int
    public let currentFileName: String
    public let bytesPerSecond: Double
    public let estimatedSecondsRemaining: Double?
}

public struct TransferJob: Identifiable, Sendable {
    public let id: UUID
    public let kind: TransferKind
    public let sources: [URL]
    public let destinationDirectory: URL
    public let sourceVolumeIdentifier: String?
    public let targetVolumeIdentifier: String?
    public var state: JobState
    public var conflictAction: ConflictAction?
    public let createdAt: Date
}
```

#### B. Konflikt Modellari (`ConflictResolution.swift`)
```swift
public struct ConflictDetails: Equatable, Sendable {
    public let sourceURL: URL
    public let targetURL: URL
    public let sourceSize: Int64
    public let targetSize: Int64
    public let sourceModified: Date
    public let targetModified: Date
    public let isSourceNewer: Bool
}

public enum ConflictAction: Equatable, Sendable {
    case overwrite
    case overwriteAll
    case overwriteIfOlder
    case overwriteIfSizeDiffers
    case skip
    case skipAll
    case autoRename
    case resume
    case cancel
}
```

#### C. Undo / Redo Tizimi (`UndoStack.swift`)
```swift
public enum UndoAction: Sendable {
    case rename(from: URL, to: URL)
    case move(items: [(source: URL, destination: URL)])
    case copy(createdItems: [URL])
    case trash(items: [(originalURL: URL, trashedURL: URL)])
}

public struct UndoEntry: Identifiable, Sendable {
    public let id: UUID
    public let description: String
    public let action: UndoAction
    public let timestamp: Date
}
```

---

### 2.2. Fayl Tizimi qatlami (`CommanderFileSystem`)

#### A. `TransferQueue` Engine (`TransferQueue.swift`)
- Markaziy `actor TransferQueue`:
  - `activeJobs: [UUID: TransferJob]`
  - `pendingJobs: [TransferJob]`
  - `completedHistory: [TransferJob]`
- **Concurrency siyosati**:
  - Har bir drayv (Volume) uchun alohida navbat boshqaruvchisi.
  - Agar yangi job allaqachon transfer bajarilayotgan diskka tegishli bo'lsa, `pending` holatda kutadi.
  - Har xil disklarga tegishli bo'lsa, parallel boshlanadi.
  - Har bir job uchun qo'lda `startImmediately()`, `pause()`, `resume()`, `cancel()` imkoniyati.

#### B. Nusxalash dvigateli (`StreamFileCopier.swift`)
1. **APFS Clone Optimization**:
   - `clonefile(srcPath, dstPath, 0)` tekshiriladi.
   - Agar manba va nishon bitta APFS diskida bo'lsa, nusxalash deyarli 0 millisekundda va disk hajmini egallamasdan bajariladi.
2. **Chunked Streamed Copying**:
   - Boshqa disklar / SMB / FAT32 uchun: 2 MB buffer orqali streaming.
   - Tezlik va ETA hisoblash (har 200 ms yangilanadi).
   - `resume` so'ralganda: mavjud nishon faylining hajmi o'qilib, manba faylidan o'sha baytdan boshlab o'qiladi (`FileHandle.seek`).
3. **Cancellation & Pause tekshiruvi**:
   - Har bir buffer chunk'dan keyin `Task.isCancelled` yoki `job.isPaused` tekshiriladi, bu esa dasturni hech qachon bloklamasligini ta'minlaydi.

---

### 2.3. Controller qatlami (`CommanderController`)

- `WindowModel` TransferQueue bilan bog'lanadi:
  - F5 / F6 bosilganda `TransferJob` yaratiladi va navbatga topshiriladi.
  - Konflikt chiqqanda `model.presentConflict(details)` chaqiriladi.
  - `UndoManager` integratsiyasi: har bir yakunlangan F5/F6/Rename/Trash amali avtomatik `undoStack` ga qo'shiladi.
  - `⌘Z` va `⇧⌘Z` buyruqlari tegishli teskari amalni bajaradi.

---

### 2.4. AppKit / SwiftUI UI qatlami (`App/`)

#### A. Status Bar Transfer Widget (`TransferStatusWidget.swift`)
- Oynaning pastki qismida joylashadi:
  - Mini-progress bar.
  - Joriy tezlik: masalan, `⚡ 42.5 MB/s` va qolgan vaqt `⏱ 00:35`.
  - Bosilganda `TransferManagerSheet` ochiladi.

#### B. Transfer Manager Sheet (`TransferManagerSheet.swift`)
- In-App Modal Sheet (asosiy oynaning ustida ochiladi, `Esc` bilan yopiladi):
  - Barcha faol va navbatdagi transferlar ro'yxati.
  - Har bir amal uchun: Pause / Resume / Cancel tugmalari.
  - Har bir fayl uchun alohida progress va umumiy progress.
  - Drag & Drop yoki tugmalar orqali navbat tartibini o'zgartirish (Up / Down).

#### C. Advanced Conflict Sheet (`ConflictDialogSheet.swift`)
- To'qnashuv paytida chiquvchi zamonaviy dialog:
  - Chapda: **Mavjud fayl (Target)** — hajmi, sanasi, qizil/kulrang ko'rsatkich.
  - O'ngda: **Yangi fayl (Source)** — hajmi, sanasi, yashil "Yangi" ko'rsatkichi.
  - Markazda: Rasm / fayl thumbnail preview.
  - Amallar:
    - `[ Almashtirish (Overwrite) ]`
    - `[ Yangiroq bo'lsa (If Older) ]`
    - `[ Hajmi farq qilsa (If Size Differs) ]`
    - `[ O'tkazib yuborish (Skip) ]`
    - `[ Qayta nomlash (Auto-rename) ]`
    - `[ Davom ettirish (Resume) ]` (agar qisman fayl bo'lsa)
  - `[x] Barcha keyingi to'qnashuvlarga qo'llash (Apply to all)`

---

## 3. Testlash va Verifikatsiya strategiyasi

1. **Unit Testlar (TDD)**:
   - `TransferQueueTests`: ketma-ketlik, parallelizm, smart concurrency, pauza/davom ettirish.
   - `StreamCopierTests`: oddiy nusxalash, APFS clone, chunked streaming, resume (qolgan baytdan davom ettirish), cancel chala faylni tozalashi.
   - `ConflictResolutionTests`: `overwriteIfOlder`, `autoRename` nom generatsiyasi, `skipAll`.
   - `UndoStackTests`: rename undo, move undo, copy undo (trash copies), zanjirli ko'p bosqichli undo/redo.
2. **Benchmark & Performance**:
   - APFS clone benchmarking: 10 GB hajmli virtual fayl nusxalanishi ≤ 50 ms.
   - RAM monitoring: Katta transferlar paytida RAM 75 MB dan oshmasligi (streaming I/O).
3. **UI Smoke Testlar**:
   - Status bar widgetining paydo bo'lishi va Sheet ochilishi.

---

## 4. Rejalashtirilgan Bosqichlar (Sub-phases)

- **2A**: `CommanderCore` modellari va `TransferQueue` + `UndoStack` dvigateli (TDD).
- **2B**: `StreamFileCopier` (APFS clone + chunked streaming + resume + speed/ETA).
- **2C**: Kengaytirilgan Konflikt dialogi (UI + Taqqoslash mantiqi).
- **2D**: Transfer Manager Sheet va Status Bar UI integratsiyasi.
- **2E**: Undo / Redo (`⌘Z`, `⇧⌘Z`) integratsiyasi va to'liq tekshiruv.
