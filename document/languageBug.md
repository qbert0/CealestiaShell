# Language / Input Method — Bug Report

---

## Tình huống gặp lỗi

**Triệu chứng**: Icon bàn phím trên status bar hiển thị sai input method sau khi người dùng đổi IM.

**Các bước tái hiện**:
1. Mở shell. Icon bar hiển thị đúng IM hiện tại (VD: `VI`)
2. Nhấn phím tắt fcitx5 (Ctrl+Space / Super+Space) để chuyển sang IM khác (VD: `EN`)
3. → **Icon bar vẫn hiển thị `VI`** — không cập nhật
4. Mở popout (click icon) → popout hiển thị đúng (active row đổi), nhưng icon bar vẫn sai
5. Tương tự nếu đổi IM qua tray icon của fcitx5

**Không xảy ra lỗi khi**:
- Đổi IM bằng cách click trực tiếp trong popout shell (dùng `switchTo()`)
- Khởi động lại fcitx5
- Khởi động lại shell

---

## Lỗi do đâu

### So sánh hai phiên bản

**Bản cũ — XKB + Hyprland** (event-driven, không lỗi):
```
người dùng đổi layout
    → Hyprland bắn IPC event "kblayout"
    → Hypr.qml nhận event, cập nhật kbLayoutFull
    → StatusIcons.qml đọc Hypr.kbLayout → bar cập nhật ngay
```

**Bản mới — fcitx5** (thiếu cơ chế lắng nghe, gây lỗi):
```
người dùng đổi IM
    → fcitx5 thay đổi nội bộ
    → KHÔNG emit D-Bus signal nào về IM hiện tại
    → Fcitx5.qml không biết → currentIM giữ giá trị cũ → bar hiển thị sai
```

### Vì sao fcitx5 không có signal?

Đã introspect D-Bus interface của fcitx5 (`org.fcitx.Fcitx.Controller1`) — chỉ có **1 signal**:

```xml
<!-- từ: dbus-send --session --print-reply --dest=org.fcitx.Fcitx5 /controller
         org.freedesktop.DBus.Introspectable.Introspect -->

<interface name="org.fcitx.Fcitx.Controller1">
  <signal name="InputMethodGroupsChanged" />  <!-- chỉ fire khi LIST IM thay đổi -->
  <!-- KHÔNG có: CurrentInputMethodChanged, ActiveIMChanged, hay bất kỳ signal nào khác -->
</interface>
```

Đã xác minh thực tế bằng `dbus-monitor`:

```bash
dbus-monitor --session "type='signal',interface='org.fcitx.Fcitx.Controller1'" &
fcitx5-remote -t   # toggle IM
# → KHÔNG có output nào từ Controller1
```

Kết luận: **fcitx5 không thông báo qua D-Bus khi đổi IM hiện tại**. Đây là giới hạn của fcitx5, không phải lỗi shell.

### Vị trí lỗi trong code

`services/Fcitx5.qml` (trước khi sửa):

```qml
// currentIM chỉ được cập nhật tại 2 thời điểm:

// 1. Khi startup
Component.onCompleted: {
    initProc.running = true;  // lấy currentIM một lần duy nhất
    ...
}

// 2. Khi fcitx5 restart (NameOwnerChanged signal)
stdout: SplitParser {
    onRead: line => {
        if (line.includes("NameOwnerChanged"))
            initProc.running = true;   // chạy lại initProc khi fcitx5 tắt/bật
        ...
    }
}

// KHÔNG có cơ chế nào bắt IM change trong phiên làm việc bình thường
```

---

## Cách khắc phục

Vì fcitx5 không emit signal, giải pháp duy nhất là **polling** `fcitx5-remote -n` (một D-Bus call nhẹ, < 10ms). QML property binding đảm bảo `onCurrentIMChanged` **chỉ fire khi giá trị thực sự thay đổi** — không có animation hay re-render giả khi poll trả về cùng IM.

---

## Files đã sửa

### 1. `services/Fcitx5.qml`

**Thay đổi 1** — Thêm `pollTimer` (dòng 59–70 sau khi sửa):

```diff
     Component.onCompleted: {
         initProc.running = true;
         listProc.running = true;
         watcher.running = true;
     }

+    // fcitx5 emits no D-Bus signal when the active IM changes (only InputMethodGroupsChanged
+    // exists on Controller1). Poll fcitx5-remote -n to stay in sync with external switches
+    // (keyboard shortcut, tray icon). QML property binding suppresses spurious signals when
+    // the value hasn't actually changed.
+    Timer {
+        id: pollTimer
+
+        interval: 500
+        running: root.available
+        repeat: true
+        onTriggered: if (!initProc.running) initProc.running = true
+    }
+
     // Persistent watcher via dbus-monitor.
```

**Vị trí**: Trước block `watcher` Process, sau `Component.onCompleted`.

**Logic của pollTimer**:
- `interval: 500` → poll mỗi 500ms (đủ nhanh để người dùng không nhận ra độ trễ)
- `running: root.available` → tự động dừng khi fcitx5 tắt, tự động chạy khi fcitx5 bật
- `repeat: true` → lặp liên tục
- `if (!initProc.running)` → không chồng process nếu lần poll trước chưa xong

---

**Thay đổi 2** — Cập nhật comment của `initProc` (dòng 110–111):

```diff
-    // Runs once at startup and whenever fcitx5 restarts.
-    // No periodic polling — IM state is maintained via optimistic updates in switchTo().
+    // Runs once at startup, whenever fcitx5 restarts, and periodically via pollTimer.
+    // Optimistic update in switchTo() keeps state in sync for in-shell switches.
```

---

## Bảng tác động sau khi sửa

| Thao tác | Trước fix | Sau fix |
|---|---|---|
| Đổi IM bằng phím tắt fcitx5 | ❌ Bar không cập nhật | ✅ Cập nhật trong ≤ 500ms |
| Đổi IM qua tray icon fcitx5 | ❌ Bar không cập nhật | ✅ Cập nhật trong ≤ 500ms |
| Click đổi IM trong popout shell | ✅ Optimistic update ngay | ✅ Không đổi (vẫn instant) |
| Fcitx5 restart | ✅ NameOwnerChanged → sync | ✅ Không đổi |
| Fcitx5 không chạy | ✅ Fallback Hypr.kbLayout | ✅ Không đổi |

---

## Ghi chú cho tương lai

Nếu fcitx5 sau này thêm signal `CurrentInputMethodChanged` vào D-Bus interface, nên:
1. Xóa `pollTimer`
2. Thêm filter vào `watcher` dbus-monitor
3. Thêm handler `else if (line.includes("CurrentInputMethodChanged")) initProc.running = true`

Để kiểm tra xem signal đã được thêm chưa:
```bash
dbus-send --session --print-reply --dest=org.fcitx.Fcitx5 /controller \
  org.freedesktop.DBus.Introspectable.Introspect | grep signal
```
