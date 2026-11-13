# Phase 2A Implementation Plan: Transfer Queue va UndoStack Yadrosi

Sana: 2026-11-14  
Spec: `docs/superpowers/specs/2026-11-14-phase2-file-operations-design.md`  
Qamrov: `CommanderCore` va `CommanderFileSystem` modullari uchun Transfer Queue va Undo tizimi asoslari (TDD).

---

## 1. Vazifalar

### Task 1: Transfer Modellari (`CommanderCore`)
- Fayllar:
  - `Packages/CommanderKit/Sources/CommanderCore/Transfer/TransferJob.swift`
  - `Packages/CommanderKit/Sources/CommanderCore/Transfer/ConflictResolution.swift`
  - `Packages/CommanderKit/Tests/CommanderCoreTests/TransferModelTests.swift`
- Modellari:
  - `TransferKind`: `.copy`, `.move`
  - `JobState`: `.queued`, `.running(progress)`, `.paused`, `.resolvingConflict`, `.completed`, `.failed(message)`, `.cancelled`
  - `TransferProgress`: baytlar, fayllar, joriy fayl, tezlik (bytes/s), ETA
  - `TransferJob`: ID, kind, sources, destination, volume identifiers, state, conflictAction
  - `ConflictDetails` va `ConflictAction`
- Testlar: Holat o'tishlari, progress formatlash, JSON serialize/deserialize.

### Task 2: Undo / Redo Modellari (`CommanderCore`)
- Fayllar:
  - `Packages/CommanderKit/Sources/CommanderCore/Undo/UndoStack.swift`
  - `Packages/CommanderKit/Tests/CommanderCoreTests/UndoStackTests.swift`
- Mantiq:
  - `UndoAction`: `.rename(from:to:)`, `.move(items:)`, `.copy(created:)`, `.trash(items:)`
  - `UndoEntry`: ID, tavsif, vaqt, action
  - `UndoStack`: `push(entry)`, `undo() -> UndoAction?`, `redo() -> UndoAction?`, `canUndo`, `canRedo`, maksimal sig'im (default: 50)
- Testlar: ketma-ket amallar, undo/redo tartibi, stack to'lganda eskilarni tozalash, yangi amal kelganda redo tarixini tozalash.

### Task 3: Volume Identifier & Resolver (`CommanderFileSystem`)
- Fayllar:
  - `Packages/CommanderKit/Sources/CommanderFileSystem/VolumeResolver.swift`
  - `Packages/CommanderKit/Tests/CommanderFileSystemTests/VolumeResolverTests.swift`
- Mantiq:
  - URL'dan `volumeIdentifier` va `isLocalVolume` aniqlash (`URLResourceValues`).
  - Ikki URL bir xil jismoniy drayvda ekanligini tezkor aniqlash (`isSameVolume(url1, url2)`).

### Task 4: Markaziy TransferQueue Engine (`CommanderFileSystem`)
- Fayllar:
  - `Packages/CommanderKit/Sources/CommanderFileSystem/TransferQueue.swift`
  - `Packages/CommanderKit/Tests/CommanderFileSystemTests/TransferQueueTests.swift`
- Mantiq:
  - `actor TransferQueue`:
    - `enqueue(sources:destination:kind:) -> UUID`
    - `pause(id:)`, `resume(id:)`, `cancel(id:)`
    - `startImmediately(id:)`
    - Smart Concurrency qoidasi: Bir xil hajmda 1 ta aktiv oqim; turli hajmlarda parallel oqimlar.
    - Delegat yoki AsyncStream orqali progress hodisalarini tarqatish (`events: AsyncStream<TransferEvent>`).
- Testlar:
  - Bitta volume'ga 2 ta job tushganda: ikkinchisi kutadi, birinchisi tugagach boshlanadi.
  - Ikki xil volume'ga tushganda: ikkalasi bir vaqtda running bo'ladi.
  - Pause va resume buyruqlari to'g'ri ishlashi.
  - Cancel qilinganda job to'xtashi va keyingisi ishga tushishi.

---

## 2. Tekshirish mezonlari

- Barcha testlar: `swift test --package-path Packages/CommanderKit` muvaffaqiyatli o'tishi kerak.
- Kod 100% thread-safe va `Sendable` talablariga mos bo'lishi kerak.
- Xotira sizib chiqishi (leak) bo'lmasligi va Swift concurrency warnings bo'lmasligi kerak.
