# Code review: KISS / DRY / YAGNI / boshqa principle'lar

**Sana:** 2026-11-01 · **Qamrov:** 1A–1E dagi barcha source (~4 500 qator): `Packages/CommanderKit` (CommanderCore, CommanderController, CommanderFileSystem) + `App/`. Testlar faqat kerak bo'lganda ko'rildi.

**Ustuvorliklar:** P1 — tekin foyda, xavfsiz qilish · P2 — o'rtacha foyda, sinchkilik talab qiladi · P3 — ixtiyoriy / kuzatishda.

---

## Umumiy xulosa

Kod bazasi principle'larga **yaxshi amal qiladi**. Kuchli tomonlar:

- Qatlam ajratilishi aniq: Core (UI'siz, testlanadigan) → Controller (barcha harakatlar `Command` orqali) → FileSystem (AppKit'siz) → App (faqat AppKit glue). Bu `AGENTS.md` dagi kelishilgan yo'nalishning o'zi.
- YAGNI galaktik darajada bajarilgan: dependency yo'q, abstraksiya faqat sinov uchun kerak joyda (`WindowEffects`, `FilePasteboard`, `Trasher` protocol'lari — bittadan real implementatsiya + test fake'i).
- Har murakkab qaror (generation guard, prompt queue, BatchRename'nin ikki qadamli almashtirishi) izoh bilan asoslangan — izohlar "nima"ni emas "nima uchun"ni tushuntiradi.
- Kichik named type'lar (`StepResult`, `CancelFlag`, `LoadResult`) yirik tuple/toggle'lar o'rnida — o'qilishi oson.

Topilgan muammolar asosan mayda: bitta o'lik API, 3–4 joyda takrorlangan ikkita kichik helper, ikkita presenter'ning turicha lifetime pattern'i. Hech biri darhol buzilmaydi; quyidagi ro'yxat asosan 1F'dan oldin bir kechada yopiladigan ishlar.

| Bo'lim | P1 | P2 | P3 |
|---|---|---|---|
| DRY | 2 | 3 | 2 |
| YAGNI | 0 | 0 | 2 |
| KISS | 0 | 1 | 2 |
| Robustness / perf | 0 | 1 | 4 |

---

## DRY

### D1. `lstat` orqali "exists" va "same file" to'rt nusxada — P1

Bir modulda (`CommanderFileSystem`) bir xil mantiq to'rt joyda:

- `OperationSupport.swift:62` — `pathExists` (lstat)
- `BatchRename.swift:74` — `exists` (aynan shu lstat, yana bir marta yozilgan)
- `OperationSupport.swift:67–83` — `FileIdentity` (dev + inode), `isSameDirectory`
- `FileActions.swift:34` — `isSameFile` (dev + inode, yana bir marta)
- `BatchRename.swift:79` — `sameFile` (dev + inode, uchinchi marta)

**Nima uchun muammo:** "same file" ta'rifi kelajakda o'zgarsa (masalan, `st_gen` yoki case-insensitive solishtirish qo'shilsa) uch joyni birdek yangilash kerak bo'ladi — bittasi unutilsa, nozik bug.

**Yechim:** hammasi bir modulda, shuning uchun `OperationSupport`ga `func sameFile(_ a: URL, _ b: URL) -> Bool` (mavjud `FileIdentity` asosida) qilib chiqarish va `FileActions`/`BatchRename`dagi privat nusxalarni o'chirish; `BatchRename.exists` o'rniga `pathExists`. Taxminan −20 qator, xatti-harakat o'zgarmaydi (testlar qamrab turadi).

### D2. `NSEvent.ModifierFlags` ↔ `KeyChord.Modifiers` konvertatsiyasi uch nusxada — P1

NSEvent flag'laridan `KeyChord.Modifiers` yasash bir xil 4-qatorli blok:

- `KeyRouter.swift:36–41`
- `FileTableView.swift:37–40` (bu yerda ataylab `.control` tushirilgan — ctrl-click kontekst menyu)
- `ShortcutRecorder.swift:45–50`

Teskarisi (`KeyChord.Modifiers` → NSEvent) esa `MainMenu.swift:101–107`da.

**Nima uchun muammo:** AppKit bridge — bitta joyda bo'lishi kerak. Nusxalar allaqachon farq qiladi (uchinchisi `.control`ni tushiradi), ya'ni drift boshlangan.

**Yechim:** `App/`da kichik fayl (masalan `KeyChord+AppKit.swift`):

```swift
extension KeyChord.Modifiers {
    init(_ flags: NSEvent.ModifierFlags) { ... }   // 4 ta flag
    var nsEventFlags: NSEvent.ModifierFlags { ... }
}
```

`FileTableView` ctrl-clickni qisqartirib yuborganidan keyin bu init'ga yetib bormaydi, shuning uchun to'liq versiyadan foydalanishi xavfsiz.

### D3. "Manbaga tushirish / o'sha papkaga ko'chirish" qoidalari ikki implementatsiyada — P2

Drag & drop qoidalari `DropPolicy.operation`da (`WindowModel+Files.swift:11–18`): manba destination ichida → `.none`; barcha manbalar to'g'ridan-to'g'ri destinationda → `.none`.

Copy To dialogi xuddi shu qoidalarni qaytadan yozgan (`WindowModel+Destinations.swift:92–99`): `intoSource` (starts-with tekshiruvi) va `alreadyThere` (deletingLastPathComponent solishtiruvi) — so'ng beep.

**Nima uchun muammo:** Finder'ning qoidasi ikki joyda yashaydi; bittasiga tuzatish kiritilsa, drag & drop va Copy To turlicha ishlay boshlaydi. Har ikki yo'lda natija baribir `beep`, ya'ni `DropPolicy` tomonidan `.none` qaytarilishining aynan boshqa sozi yo'q.

**Yechim:** `chooseDestination` ichidagi tekshiruvni `dropOperation(sources, to: destination, forceCopy: false) == .none` bilan almashtirish (`sources.isEmpty` u yerda allaqachon guard qilingan). `DropPolicy`ga bitta izoh: "bu qoida Copy To dialogida ham qo'llanadi".

### D4. Fayl nomi validatsiyasi qoidalari ikki joyda — P2

`FileActions.rename` (`FileActions.swift:19–21`): bo'sh nom, `/`, `:` — xato.
`MultiRename.preview` (`MultiRename.swift:66–68`): `name.isEmpty`, `contains("/")`, `contains(":")` — `RenameProblem.invalidCharacter/empty`.

Xabarlari ham parallel: `RenameText.message` (Controller) va `MultiRenameState.describe` (App).

**Nima uchun muammo:** qoidalar tarixan o'zgaradi (masalan keyinchalik `:`ga ruxsat berish yoki boshqa taqiqlangan belgi qo'shish) — ikki modul sinxronlashishi kerak bo'ladi.

**Yechim:** CommanderCore'da bitta qoida-funksiya (masalan `FileNameRule.problem(_ name: String) -> Problem?` yoki oddiy enum qaytaruvchi statik metod); `FileActions` uni `RenameError`ga, `MultiRename` `RenameProblem`ga o'giradi. Xabarlar UI qatlamida qolaveradi.

### D5. Stem/extension ajratish uch nusxada, qoidalari nozik farq qiladi — P2

- `FileItem.ext(of:kind:)` + `baseName` (`FileItem.swift:53–65`) — `pathExtension`, yetakchi nuqta va oxirgi nuqta istisnosi bilan
- `UniqueName.split` (`UniqueName.swift:23–26`) — `lastIndex(of: ".")`, xuddi shu istisnolar, lekin ext nuqta bilan qaytadi
- `RenameSelection.editableLength` (`WindowModel+Files.swift:21–32`) — yana `lastIndex(of: ".")`

**Nima uchun muammo:** uchalasi bir xil "nuqta qayerda?" qoidasini amalga oshiradi; `FileItem` va `UniqueName` **bir modulda** (CommanderCore), ya'ni birlashtirish to'siqsiz. `RenameSelection` Controller'da, lekin `FileItem.baseName`ni ishlatib soddalashtirilishi mumkin.

**Yechim:** ehtiyotkorlik bilan: `CommanderCore`da bitta `NameParts` (yoki `FileItem.stemExt(of:)`) chiqarib, uchala joyni unga yo'naltirish. **Diqqat:** hozirgi nozik farqlar (oxirgi nuqtali `file.` holati) testlar bilan qamrab olinganini tekshirib, xatti-harakatni aynan saqlash kerak. Bu P2, chunki foydasi kichik va xavfi (subtle rename farqlari) mavjud — sinchkilik bilan qilinsa arziydi.

### D6. `SizeRow` va `OperationRow` deyarli bir xil klasslar — P3

`FooterView.swift:128–218`: ikkala privat klass ham progress bar (160pt) + label + spacer + Cancel tugmasidan iborat, `update` farqi bilan.

**Yechim:** bitta `ProgressRow` (init'da label/accessibility id, `update(progress:max:label:)`). Taxminan −40 qator. Ixtiyoriy — hozirgi ko'rinish ham o'qiladigan.

### D7. `Session.addRecentServer / addRecentDestination / addRecentPattern` — uch karra MRU naqshi — P3

`Session.swift:66–83`: dedupe → index 0'ga insert → `prefix(limit)`. Uch marta, limit konstantalari bilan.

**Yechim:** `private mutating func moveToFront<T: Equatable>(_ item: T, into list: inout [T], limit: Int)`. Diqqat: `addRecentDestination`标准化 qiladi (standardize) — parametr sifatida transform o'tkazish mumkin. 18 → 8 qator. Arziydiganmi — savol ostida; shunchaki kuzatishda bo'lsin, to'rtinchisi paydo bo'lsa birlashtirish kerak.

---

## YAGNI

### Y1. `WindowState.otherPane` production'da ishlatilmaydi — P3

`PaneState.swift:63–66` — getter va setter bor, lekin grep bo'yicha production kodda bir ham qo'llanilmagan (faqat `PaneStateTests`). `transfer()` o'rniga `tab(side == .left ? .right : .left)` yozilgan.

**Yechim:** o'chirish tashqarisida hech narsa yo'qolmaydi; 2-bosqichda kerak bo'lsa qayta qo'shiladi (YAGNI: "kelajakda kerak bo'ladi" — hozirgina yoziladigan sabab emas). Kamida: testdan ham o'chirish yoki izoh bilan "test uchun" deb belgilash.

### Y2. `SettingsStore` migration mexanizmi hali hech qachon ishlatilmagan — P3 (chegara holat)

`SettingsStore.swift:10, 18–19, 58–71` — `Migration` typealias, ikkita lug'at, `while version < currentVersion` sikli. Production'da migratsiya yo'q (v1), faqat testda ishlatiladi.

**Baho:** qat'iy YAGNI bo'yicha bu "hali kerak bo'lmagan infratuzilma". Lekin: v1 settings fayli allaqachon diskda va `version` maydoni yoziladi — fayl formati rivojlanishi muqarrar, mexanizm ~10 qator va test qamroviga ega. **Tavsiya: qoldirish**, lekin bu ataylab qilingan tanlov ekanini bir qatorli izoh bilan belgilash (`// v2 migratsiyasi kerak bo'lgunga qadar bo'sh`). Agar keyin ham v2 bo'lmasa — o'chirish.

---

## KISS

### K1. `CopyToPresenter` lifetime raqsi — P2

`CopyToView.swift:270–302`: `unowned self` closure'lar + `continuation` + `withExtendedLifetime(presenter) {}` — presenter'ni tirik tutishning uchta mexanizmi bir joyda. Izoh bor ("Keeps the presenter alive until the sheet is done"), lekin bu pattern mo'rt: yangi callback qo'shilsa `unowned` crash xavfi, `withExtendedLifetime` esa o'quvchi uchun ekzotik.

**Nima uchun muammo:** bir xil muammoni o'sha codebase'dagi `MultiRenamePresenter` (`MultiRenameView.swift:151`) allaqachon sodda yechgan: `static var current` — presenter'ni global hold, closure'lar kuchli ushlashdi, sheet yopilganda `current = nil`.

**Yechim:** `CopyToPresenter`ni ham xuddi shu naqshga o'tkazish (`static var current`), `unowned` va `withExtendedLifetime`ni olib tashlash. Ikkala sheet presenter'i bir naqshda bo'ladi — KISS va konsistentlik bir vaqtda.

### K2. `FooterView.renderOperations` — qayta qurish shartlarining uyalgan holati — P3

`FooterView.swift:55–87`: `showsHints`, `ids != shownOperationIDs`, `stack.arrangedSubviews.count != visible.count + (operations.count > Self.maxRows ? 1 : 0)` — uch shartli reconciliation. Qatorlar soni ≤ 4 bo'lgani uchun ID bo'yicha diff qilish erta optimizatsiyaga o'xshaydi, lekin "har progress tick'da (100ms) qayta qurish" ham to'g'ri emas.

**Yechim (ixtiyoriy):** shartlarni ikkiga qisqartirish — `ids != shownOperationIDs || showsHints` bo'lsa qayta qurish, aks holda faqat `update`. `arrangedSubviews.count` tekshiruvi `ids` bilan birga keladi ("+N more" label `ids` o'zgarmasa ko'rinmaydi). Yo'qsa qoldirish — ishlayapti, izohlangan.

### K3. `WindowModel` — 12 ta alohida mutable state o'chog'i — P3 (kuzatish)

`WindowModel.swift:33–49`: `generations`, `banners`, `versions`, `watches`, `pending`, `loadTasks`, `pageSizes`, `pendingCursor`, `folderSizesBySide`, `sizeRun`, `cutNamesByFolder`, `multiRenameUndo`. Extension'larga bo'lingani (`+Files`, `+Sizes`, `+Cut`…) fayllarni kichik saqlaydi, lekin obyektning o'zi holat markazi.

**Hozir buzilmagan** — har bo'lak izohlangan va testlangan. **Tavsiya:** hozir refactor qilmaslik (1F oldida katta churn befoyda). Lekin 1F kontekst menyusi yana state qo'shsa, `PaneSide` bo'yicha bir `PaneRuntime` struct'iga (`generation`, `version`, `watch`, `banner`, `pendingCursor`, `folderSizes`) guruhlashni o'ylash — `[PaneSide: X]` lug'atlar sonini bir nechtaga tushiradi.

---

## Robustness / performance

### R1. `validateDrop` har drag-update'da `dropOperation`ni ikki marta hisoblaydi — P2

`FileTableController.swift:215, 224`: `draggingUpdated` har sichqoncha harakatida (o'nlab marta/soniya) ikki marta chaqiriladi. `DropPolicy.operation` → `sameVolume` har chaqiriqda har manba uchun `resourceValues` (stat) qiladi. 5 000 faylli drag'da bu ko'p befoyda syscall.

**Yechim:** natijani bir marta hisoblab, lokal o'zgaruvdadan ikkala joyni boqish (funksiya ichida `let operation = model.dropOperation(...)`, so'ng `folder` sharti va return'da ishlatish). Bir qatorli tuzatish, xavfsiz.

### R2. Copy oldidan to'liq ikki marta yurish — P3

`CopyOperation.swift:56–61` + `totals` (`FolderSize.measure`): progress bar uchun har manba daraxti to'liq yurib chiqiladi, so'ng `copyTree` yana bir marta yuradi. Katta daraxtlarda metadata I/O ikki barobar.

**Baho:** bu aniq tradeoff (aniq progress bar vs. tezlik) va hozirgi tanlov oqilona. Faqat hujjatlash kerak — izoh bor, kifoya. Katta papkalarda sekinlik sezilsa, lazy totals (kopiya paytida `totalFiles`ni yangilash) alohida task bo'lsin.

### R3. O'tkazib yuborilgan elementlar progressda turlicha sanaladi — P3

- `CopyOperation.account(skipped:)` (`CopyOperation.swift:188`): skip → butun subtree hisobi qo'shiladi.
- `MoveOperation.swift:96–104` va `TrashOperation.swift:69–71`: skip bo'lsa ham `completedFiles += 1` (bitta item).

Progress bar har operatsiyada boshqacha "yuradi". Kosmetik, lekin bir izoh yoki birlashtirish arziydi — ayniqsa Move ichidagi CopyOperation ikkala semantikani aralashtirib yuboradi.

### R4. `reveal()` bir papkani ikki marta listlaydi — P3

`WindowModel+Reveal.swift:14–20`: `mutatePane { $0.newTab() }` yangi tabni meros papkasi bilan darhol `load` qiladi, so'ng `navigate` boshqa papkani yuklaydi — birinchi listing natijasi tashlanadi (generation guard ushlab turadi, xavfsiz). Kamdan-kam amal, narxi bir listing. Agar teginsa: `newTab(thenNavigateTo:)` birlashgan API yoki `newTab`'ga "load qilma" flag. Hozir qoldirish mumkin.

### R5. `PaneText.status` har renderda har item uchun `standardizedFileURL.path` — P3

`Texts.swift:16`: `folderSizes` standardize qilingan path bilan kalitlangan; status har renderda (har tugma harakatida!) barcha itemlar uchun `standardizedFileURL` string ishini qiladi. 5 000 faylda render kechikishining mayda ulushi.

**Yechim:** `folderSizesBySide`ni nom bilan kalitlash (papka ichida nomlar yagona; `sizeRun` allaqachon path'ni `calculateSizes`da bir marta oladi) yoki `status`ni faqat `folderSizes` bo'sh bo'lmaganda to'liq hisoblash. Kichik, ammo render yo'lidagi O(n) string ishini yo'q qiladi.

### R6. Mayda

- `ShortcutRecorder.swift:41`: `keyCode == 53` — magic number (Esc). `KeyChordMapper.chord(keyCode: event.keyCode, baseCharacters: event.characters(byApplyingModifiers: []), modifiers: [])?.key == "escape"` orqali tekshirish — xarita ikki manbali haqiqat bo'lib qolmasin.
- `WindowModel+Sizes.swift:76`: `if let measured = measured ?? nil` — `try?` ikki qatlamli optional; `?? nil` to'g'ri lekin chalkash. `try?` natijasini `flatMap`/`?? nil` bilan darhol tekislab, izoh qoldirish.
- Fayl joylashuvi: `DragFiles` va `DropButton` `SpringLoader.swift` ichida yashaydi (`SpringLoader.swift:32–125`) — nomi bilan mos emas. `DropButton.swift`ga ajratish (yoki faylni `DragSupport.swift` deb nomlash).

---

## Nima QILMASLIK kerak (over-engineering xavfi)

Review topilmalari kichik — bu tasodif emas. Quyidagilarni "tuzatish"ga urinmang:

1. **`WindowModel`ni event-bus / reducer arxitekturaga o'tkazish** — hozirgi `Command` + extension bo'linishi yetarli; abstraksiya faqat 2-bosqichda ko'p window talab qilinsa qo'shiladi.
2. **`DropPolicy`ni protocol qilish** yoki D3 uchun yangi tip tizimi — oddiy enum funksiya qolishi kerak.
3. **Test fake'larini mock kutubxonasi bilan almashtirish** — qo'lda yozilgan `Fakes.swift`/`RecordingDelegate.swift` aynan right size.
4. **Y1/Y2'dan ilhomlanib boshqa "kelajakda kerak" API'larni oldindan yozish** — aksincha: 1F spec'ida talab qilingandagina qo'shilsin.

---

## Tavsiya etilgan tartib

1. **Bir kechada (P1):** D1 (`sameFile`/`pathExists` birlashtirish), D2 (ModifierFlags konvertatsiyasi), Y1 (`otherPane`ni o'chirish), R1 (validateDrop bir hisob), R6 maydalar. `swift test` + smoke test bilan tasdiqlash.
2. **1F spec yozishdan oldin (P2):** K1 (CopyToPresenter → `static current` naqshi), D3 (Copy To qoidalarini `DropPolicy`ga topshirish), D4 (nom validatsiyasi birlashtirish) — kontekst menyu 1F ushbu joyni tegadi (menyu `performFileCommand`ga bog'lanadi), avval yopilsa konflikt kamayadi.
3. **Kuzatishda (P3):** K3 (WindowModel holati), D5 (stem/ext — sinchkilik bilan), D6, D7, R2–R5. Har biri alohida kichik commit bo'lsin.
