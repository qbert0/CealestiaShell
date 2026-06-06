# Bug: Duplicate Instances & Lock Bypass When Connecting New Monitor

## Triệu chứng (Symptoms)

- Cắm màn hình mới → thanh bar, cursor bị **nhân đôi** (duplicate bars/cursors)
- Màn hình đang **khoá** + cắm màn mới → lock screen biến mất, desktop lộ ra (**lỗ hổng bảo mật**)
- Giao diện **nháy/flicker** rồi mất rồi xuất hiện lại

---

## Nguyên nhân gốc rễ (Root Cause)

### Luồng sự kiện

```
Cắm màn mới
  → kanshi phát hiện output mới
  → switch sang profile phù hợp
  → chạy exec của profile
```

### Bug A — Duplicate instances (màn không khoá)

Exec mặc định cũ trong `services/Kanshi.qml` (hàm `_write()`):
```
sleep 2 && caelestia shell -k && sleep 1 && caelestia shell -d
```

| Bước | Exec | shell-watchdog.sh (`~/.config/hypr/Scripts/shell-watchdog.sh`) |
|------|------|-------------------|
| 1 | `caelestia shell -k` → kill quickshell | watchdog phát hiện process chết → **auto-restart instance #1** |
| 2 | `sleep 1` | instance #1 đang khởi động |
| 3 | `caelestia shell -d` → **start instance #2** | — |

**Kết quả**: 2 quickshell chạy song song → duplicate bar, cursor đôi, widgets nhân đôi.

### Bug B — Lock bypass (màn đang khoá)

Exec cũ không kiểm tra trạng thái lock. Khi screen đang locked:
1. `caelestia shell -k` kill shell → `WlSessionLock` bị release
2. Compositor **nhả khoá ngay** trước khi user unlock
3. Desktop lộ ra trong ~1s → **lỗ hổng bảo mật**

### Bug C — Missed deferred restart (edge case)

`deferredRestartProc` (xử lý flag `/tmp/qs-restart-needed` sau unlock) chỉ được trigger từ
`LogindManager.onUnlockRequested`. Nhưng unlock còn có thể đến từ:
- `handleIdleAction("unlock")` (idle config trực tiếp)
- `CustomShortcut "unlock"` (`Lock.qml:60`)

Cả hai path này gọi `lock.lock.unlock()` nhưng không qua logind
→ flag `/tmp/qs-restart-needed` không bao giờ được xử lý → shell không restart sau khi cắm màn khi locked.

### Cơ chế deferred restart — đã có nhưng chưa đủ

`modules/IdleMonitors.qml` có sẵn `deferredRestartProc`:
```qml
// Sau unlock → 2s → check flag → chỉ kill (watchdog tự restart, không duplicate)
command: ["bash", "-c",
  "if [ -f /tmp/qs-restart-needed ]; then rm -f /tmp/qs-restart-needed; caelestia shell -k; fi"]
```

Mechanism này đúng. Vấn đề là:
1. Exec cũ không dùng flag này (dùng kill+restart trực tiếp)
2. Trigger chỉ từ logind, thiếu unlock paths khác

---

## Kiến trúc Lock IPC

`modules/lock/Lock.qml:63-77` định nghĩa IPC handler:
```qml
IpcHandler {
    function isLocked(): bool { return lock.locked; }
    target: "lock"
}
```

→ `caelestia shell lock isLocked` gọi qua quickshell IPC → trả về `"true"` hoặc `"false"`.

Các profile kanshi hiện tại đã dùng cách này đúng:
```bash
timeout 3 caelestia shell lock isLocked 2>/dev/null | grep -qi "true" \
  && touch /tmp/qs-restart-needed \
  || caelestia shell -k
```

---

## Các thay đổi đã thực hiện

### 1 · `services/Kanshi.qml` — hàm `_write()`, dòng 231

**Mục đích**: Đổi exec mặc định cho profile mới từ kill+restart trực tiếp sang
smart IPC check (nhất quán với các profile hiện có).

```diff
- || "sleep 2 && caelestia shell -k && sleep 1 && caelestia shell -d"
+ || "timeout 3 caelestia shell lock isLocked 2>/dev/null | grep -qi \"true\" && touch /tmp/qs-restart-needed || caelestia shell -k"
```

**Logic mới:**
- Query IPC `lock.isLocked()` (3s timeout)
- Nếu locked → tạo flag `/tmp/qs-restart-needed` → deferred restart sau unlock
- Nếu không locked → chỉ kill → watchdog restart (không có `-d`, không duplicate)

**Lưu ý**: Không ảnh hưởng profile cũ đã có `exec`. Chỉ áp dụng khi tạo profile mới.

---

### 2 · `modules/IdleMonitors.qml` — thêm vào sau `deferredRestartProc`

**File**: `modules/IdleMonitors.qml`
**Dòng thêm vào**: 63–91 (sau `deferredRestartProc`)

**Mục đích A — Lock state indicator** (dự phòng khi IPC unavailable):

```qml
// Lock-state indicator: kanshi exec reads /tmp/qs-session-locked to decide
// whether to defer the shell restart until after unlock.
Process {
    id: lockSetProc
    command: ["bash", "-c", "touch /tmp/qs-session-locked"]
}

Process {
    id: lockClearProc
    command: ["bash", "-c", "rm -f /tmp/qs-session-locked"]
}
```

Ghi/xoá `/tmp/qs-session-locked` song song với lock state thực tế để exec có thể
fallback kiểm tra file nếu IPC chậm.

**Mục đích B — `Connections` bao phủ mọi unlock path** (dòng 75–87):

```qml
Connections {
    target: root.lock.lock
    function onLockedChanged() {
        if (root.lock.lock.locked) {
            lockSetProc.running = false; lockSetProc.running = true
        } else {
            lockClearProc.running = false; lockClearProc.running = true
            // Bao phủ unlock KHÔNG qua LogindManager.onUnlockRequested:
            // - handleIdleAction("unlock")
            // - CustomShortcut "unlock" (Lock.qml:60)
            deferredRestartTimer.restart()
        }
    }
}
```

`LogindManager.onUnlockRequested` chỉ bắn khi logind gửi signal. `WlSessionLock.unlock()`
gọi trực tiếp (từ PAM thành công hoặc từ idle action) không đi qua logind.
`Connections.onLockedChanged` bắt được **tất cả** các cách unlock.

**Mục đích C — `Component.onCompleted`** (dòng 88–91):

```qml
Component.onCompleted: {
    if (root.lock.lock.locked)
        lockSetProc.running = true
}
```

Khởi tạo đúng trạng thái nếu shell restart trong khi screen đang locked.

---

## Luồng sau khi fix

### Cắm màn, screen KHÔNG khoá

```
kanshi exec → caelestia shell lock isLocked → "false"
  → caelestia shell -k (kill only)
  → shell-watchdog.sh restart
  → 1 instance duy nhất ✓
```

### Cắm màn, screen ĐANG khoá

```
kanshi exec → caelestia shell lock isLocked → "true"
  → touch /tmp/qs-restart-needed
  → [user unlock via password/shortcut/idle action]
  → lock.lock.locked = false
  → Connections.onLockedChanged fires
  → deferredRestartTimer.restart() (2s delay)
  → deferredRestartProc runs
  → rm /tmp/qs-restart-needed && caelestia shell -k
  → shell-watchdog.sh restart
  → 1 instance, lock screen giữ nguyên trong suốt quá trình ✓
```

---

## Checklist các path đã bao phủ

| Unlock path | Trigger `deferredRestartTimer`? | Ghi chú |
|---|---|---|
| PAM password success | ✓ (qua `onUnlockRequested` + `Connections`) | Double-trigger vô hại (timer reset) |
| `handleIdleAction("unlock")` | ✓ (chỉ `Connections`) | Trước fix: bị bỏ sót |
| `CustomShortcut "unlock"` | ✓ (chỉ `Connections`) | Trước fix: bị bỏ sót |
| Logind unlock signal | ✓ (chỉ `onUnlockRequested`) | Path gốc, vẫn hoạt động |

---

## Files thay đổi

| File | Dòng | Thay đổi | Lý do |
|------|------|---------|-------|
| `services/Kanshi.qml` | 231 | Đổi default exec dùng IPC | Nhất quán với profile hiện có, fix duplicate + lock bypass |
| `modules/IdleMonitors.qml` | 63–91 | Thêm `lockSetProc`, `lockClearProc`, `Connections`, `Component.onCompleted` | Bao phủ mọi unlock path; file indicator dự phòng |

**Không thay đổi**:
- `~/.config/kanshi/config` — profile hiện có đã đúng, không cần sửa
- `modules/lock/Lock.qml` — IpcHandler `isLocked()` đã đúng, không cần sửa
- `shell-watchdog.sh` — logic watchdog đúng, không cần sửa

---

## Bug D — Kanshi options silently dropped on Save (Display Pane)

### Triệu chứng

- Bật/tắt **DPMS**, **Adaptive sync**, chọn **Scale filter**, hoặc bật **10-bit** trong display pane
  → nhấn Save → file `~/.config/kanshi/config` **không chứa** các tuỳ chọn này
- Reload lại pane → các switch reset về mặc định (không persist)

### Nguyên nhân

`services/Kanshi.qml` — hàm `serializeConfig()` (dòng 85-87) chỉ ghi:

```
output <name> enable mode WxH@HzHz position X,Y scale N transform T
```

Bốn trường kanshi **không được ghi**: `scale-filter`, `dpms`, `adaptive-sync`, `allow-high-bit-depth`.

Đồng thời `parseConfig()` (dòng 53-56) cũng không có regex để đọc 4 trường này,
nên dù file config có sẵn các giá trị đó, chúng cũng bị bỏ qua khi load.

### Hướng sửa

**`parseConfig()`** — thêm 4 regex match sau các match hiện có:

```javascript
const filterM = rest.match(/scale-filter\s+(auto|nearest|linear)/)
const dpmsM   = rest.match(/dpms\s+(on|off)/)
const asyncM  = rest.match(/adaptive-sync\s+(on|off)/)
const hbdM    = rest.match(/allow-high-bit-depth\s+(on|off)/)
```

Và set trong object output:

```javascript
scaleFilter:  filterM ? filterM[1] : "auto",
dpms:         dpmsM   ? dpmsM[1] === "on" : true,
adaptiveSync: asyncM  ? asyncM[1] === "on" : false,
tenBit:       hbdM    ? hbdM[1] === "on"  : false,
```

**`serializeConfig()`** — thêm sau `transform`:

```javascript
if (o.scaleFilter && o.scaleFilter !== "auto") l += ` scale-filter ${o.scaleFilter}`
if (o.dpms === false)  l += ` dpms off`
if (o.adaptiveSync)    l += ` adaptive-sync on`
if (o.tenBit)          l += ` allow-high-bit-depth on`
```

---

## Bug E — Canvas quá thấp khi màn hình xoay 90°/270°

### Triệu chứng

- Cắm màn hình và đặt transform = 90° hoặc 270°
  → card màn hình bị **cắt bớt** (tràn ra ngoài canvas), không thể kéo thả toàn bộ

### Nguyên nhân

`CanvasSection.qml` — `implicitHeight` (dòng 13-19):

```javascript
for (const o of Kanshi.editOutputs)
    maxY = Math.max(maxY, o.y + o.height)   // ← sai: không đổi trục khi xoay
```

Khi xoay 90°/270°, card trên canvas hiển thị với chiều cao = `o.width * zoomLevel`
(đổi trục width↔height). Nhưng công thức tính `implicitHeight` dùng `o.height`
nên có thể trả về giá trị nhỏ hơn thực tế → canvas bị crop.

Ví dụ: màn 2560×1440 xoay 90° → visual height = 2560×0.2 = 512px, nhưng tính = 1440×0.2+32 = 320px.

### Hướng sửa

```javascript
implicitHeight: {
    if (Kanshi.editOutputs.length === 0) return 120
    const rotSet = ["90","270","flipped-90","flipped-270"]
    let maxY = 1
    for (const o of Kanshi.editOutputs) {
        const r = rotSet.includes(o.transform ?? "normal")
        maxY = Math.max(maxY, o.y + (r ? o.width : o.height))
    }
    return Math.min(220, Math.max(120, maxY * Kanshi.zoomLevel + 32))
}
```

---

## Bug F — Display pane không hiển thị (runtime: sai instance đang chạy)

### Triệu chứng

- Mở control center → không thấy tab "display"
- Hoặc tab display hiện ra nhưng không có nội dung

### Nguyên nhân

Hai instance quickshell chạy song song:

| Instance | Config | Có display pane? |
|----------|--------|-----------------|
| PID cũ (started lúc 16:39) | `/etc/xdg/quickshell/caelestia/` (installed) | ✗ Không |
| PID mới (started lúc 18:55) | `~/.config/quickshell/caelestia/` (symlink → dev) | ✓ Có |

**Lý do instance cũ dùng installed version**: Khi session login lúc 16:39, ổ ngoài `/run/media/qbert/...` chưa được mount. Symlink `~/.config/quickshell/caelestia` trỏ vào đường dẫn không tồn tại → quickshell fallback sang `/etc/xdg/quickshell/caelestia/` (bản cài đặt, không có `services/Kanshi.qml` và `modules/controlcenter/display/`).

Người dùng đang tương tác với bar/control center của instance cũ → không thấy tab display.

### Hướng sửa

Kill instance installed, giữ lại instance dev:

```bash
kill <PID-của-installed-instance>
# Shell watchdog hoặc systemd sẽ restart bằng dev version
# (vì ổ ngoài đã mount, symlink hoạt động)
```

Hoặc restart toàn bộ:
```bash
pkill qs && caelestia shell -d
```

### Đã sửa

Kill PID 1091 (installed instance, `/etc/xdg/quickshell/caelestia/`). Instance mới (PID 23483) tự khởi động từ dev version với display pane.

---

## Files thay đổi (Bug D + E)

| File | Thay đổi | Lý do |
|------|---------|-------|
| `services/Kanshi.qml` | `parseConfig`: thêm parse `scale-filter`, `dpms`, `adaptive-sync`, `allow-high-bit-depth` | Không bị mất config khi load |
| `services/Kanshi.qml` | `serializeConfig`: ghi 4 trường trên khi khác default | Options không bị silently dropped khi Save |
| `modules/controlcenter/display/CanvasSection.qml` | `implicitHeight`: dùng `o.width` thay `o.height` khi xoay 90°/270° | Canvas đủ cao để hiển thị card màn hình xoay |
