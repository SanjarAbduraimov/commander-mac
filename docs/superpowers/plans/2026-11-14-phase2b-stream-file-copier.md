# Phase 2B Implementation Plan: StreamFileCopier (APFS clone + Streaming + Resume)

Sana: 2026-11-14  
Spec: `docs/superpowers/specs/2026-11-14-phase2-file-operations-design.md`  
Qamrov: `CommanderFileSystem` modulida APFS Clone va Chunked Streaming orqali yuqori tezlikdagi nusxalash dvigateli (TDD).

---

## 1. Vazifalar

### Task 1: `StreamCopier` protokoli va APFS Clone
- Fayl: `Packages/CommanderKit/Sources/CommanderFileSystem/StreamFileCopier.swift`
- Test: `Packages/CommanderKit/Tests/CommanderFileSystemTests/StreamFileCopierTests.swift`
- Mantiq:
  - Bitta APFS diskida: `clonefile(srcPath, dstPath, 0)` orqali bir zumda nusxalash.
  - Muvaffaqiyatli clone bo'lganda progress 100% ga o'tadi va disk maydoni tejaladi.
  - Agar `clonefile` `EXDEV` (turli disk) yoki `ENOTSUP` bersa, avtomatik chunked stream'ga o'tadi.

### Task 2: Chunked Stream Copying va Progress / Tezlik
- Mantiq:
  - 2 MB buffer o'lchami (`FileHandle` or POSIX `read`/`write`).
  - Har bir buffer o'qib-yozilgandan so'ng callback orqali:
    - O'tkazilgan baytlar, joriy fayl nomi, o'rtacha tezlik (bytes/s), qolgan vaqt (ETA) hisoblanadi.
  - `Task.isCancelled` yoki `isPaused` tekshiruvi: darhol xavfsiz to'xtash.

### Task 3: Resume (Chala faylni qolgan joyidan davom ettirish)
- Mantiq:
  - Nishon faylning mavjud hajmini aniqlash.
  - Manba faylida o'sha baytga `seek` qilish.
  - Qolgan qismini nishon faylining oxiriga yozish (`append`).

### Task 4: Daraxtsimon (Rekursiv) nusxalash
- Mantiq:
  - Papkalar tuzilmasini yaratish.
  - Fayllarning ruxsatnomalari (`posixPermissions`) va sanalarini (`contentModificationDate`) saqlash.
  - Har bir fayldan keyin bekor qilinishini tekshirish.

---

## 2. Tekshirish mezonlari

- `StreamFileCopierTests` da:
  - APFS clone ishlashi.
  - Katta faylni chunked nusxalash va progress to'g'ri hisoblanishi.
  - Resume: 100 baytlik fayldan 40 bayt yozilgan bo'lsa, qolgan 60 bayt davom ettirilib to'liq tiklanishi.
  - Cancel: bekor qilinganda oqim to'xtashi va resurslar (file handle'lar) yopilishi.
- Barcha `swift test` 370+ testlar muvaffaqiyatli o'tishi.
