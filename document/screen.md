# Quản lý và cấu hình màn hình

## Kiến trúc tổng quan

```
DisplayPane.qml
├── DisplayController { id: ctrl }   ← State + Logic + I/O
├── CanvasSection    { controller: ctrl }   ← Kéo-thả vị trí màn hình
├── ToolbarSection   { controller: ctrl }   ← Toggle on/off, nút Save
└── MonitorSection   { controller: ctrl }   ← Bảng cấu hình chi tiết
```

---

## Tầng dữ liệu / Service

| File | Vai trò |
|------|---------|
| `services/Screens.qml` | Singleton lọc `Quickshell.screens` theo `GlobalConfig.forScreen(name).enabled`; cung cấp `screens: list<ShellScreen>` và `isExcluded(screen)` cho các module khác |

---

## Tầng điều khiển

### `modules/controlcenter/display/DisplayController.qml`

State + Logic + I/O trung tâm cho tab Display. UI truy cập qua property `controller`.

| Phần | Nội dung |
|------|----------|
| **State** | `profiles`, `profileNames`, `activeProfile`, `editOutputs`, `selectedIdx`, `isDirty`, `busy`, `zoomLevel` |
| **Parse/Serialize** | Đọc/ghi format kanshi config (`profile name { output ... }`) |
| **Profile ops** | `loadProfile`, `addNewProfile`, `deleteProfile`, `switchToProfile` |
| **Output ops** | `updateOutput`, `snapPos` (snap-to-edge khi kéo thả) |
| **Save/Apply** | `saveConfig` → ghi file; `applyProfile` → `_write` → `_switch` |
| **I/O** | `FileView` (đọc `~/.config/kanshi/config`), `Process` (kanshictl status/reload/switch), `Timer` (delay + retry) |

Dữ liệu live lấy từ `Hypr.monitors` (Hyprland IPC) để điền `availableModes`, kích thước, refresh rate thực tế.

---

## Tầng UI

| File | Vai trò |
|------|---------|
| `modules/controlcenter/display/DisplayPane.qml` | Container chính, khởi tạo `DisplayController`, lazy-load nội dung qua `Loader`, cuộn dọc |
| `modules/controlcenter/display/CanvasSection.qml` | Dot-grid background + card mỗi monitor; drag để đặt vị trí; swap width/height khi transform 90°/270°; snap-to-edge qua `controller.snapPos` |
| `modules/controlcenter/display/MonitorSection.qml` | Bảng 4 cột cấu hình chi tiết monitor đang chọn (xem bên dưới) |
| `modules/controlcenter/display/ToolbarSection.qml` | Pill toggle enable/disable từng màn hình; nút Save (active khi `isDirty`) |

### Bố cục bảng MonitorSection (4 cột)

| Row | Cột 1 | Cột 2 | Cột 3 | Cột 4 |
|-----|-------|-------|-------|-------|
| 1 | Tên + mô tả (colspan 3) | | | Transform |
| 2 | Position X | Position Y | Scale | Scale filter |
| 3 | Width | Height | Refresh | Modes (dropdown) |
| 4 | DPMS + Adaptive sync | Custom mode | 10-bit | Mirror |
| 5 | kanshi info + link GitHub (colspan 3) | | | Nút Apply |

---

## Luồng hoạt động

```
Đọc file   : FileView → parseConfig() → profiles / profileNames
Trạng thái : kanshictl status → activeProfile → loadProfile()
Chỉnh sửa  : updateOutput() → isDirty = true
Lưu        : saveConfig() → writeProc (ghi file) → isDirty = false
Áp dụng    : applyProfile() → _write() → reloadProc → delay 500ms → switchProc
```

### Quy trình Apply chi tiết

```
applyProfile()
  └─ isDirty? → _write() → writeProc (ghi ~/.config/kanshi/config)
                              └─ onExited(0) → _switch()
  └─ !isDirty → _switch()

_switch()
  └─ reloadProc (kanshictl reload)
       ├─ onExited(≠0) → retryReloadTimer (600ms) → reloadProc lại
       └─ onExited(0)  → switchDelay (500ms) → switchProc (kanshictl switch <profile>)
```
