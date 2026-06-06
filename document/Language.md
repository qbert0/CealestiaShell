# Quản lý Ngôn ngữ / Input Method

---

## Tầng Service (Backend)

| File | Vai trò |
|------|---------|
| `services/Fcitx5.qml` | Core service Fcitx5: poll IM hiện tại qua `fcitx5-remote -n`, đọc danh sách IM từ `~/.config/fcitx5/profile`, hàm `switchTo()`, tạo label ngắn/dài (EN, VN, VI, JA...) |
| `services/Hypr.qml` | Fallback XKB: expose `kbLayout` / `kbLayoutFull`, bắn toast khi layout thay đổi, theo dõi Caps/Num Lock |

---

## Tầng UI — Icon trên Bar

| File | Vai trò |
|------|---------|
| `modules/bar/components/StatusIcons.qml` | Icon bàn phím trên status bar: hiển thị `Fcitx5.imLabel` nếu Fcitx5 khả dụng, ngược lại fallback sang `Hypr.kbLayout` (XKB). Ẩn/hiện qua `Config.bar.status.showKbLayout` |

---

## Tầng UI — Popout (Dropdown khi click icon)

| File | Vai trò |
|------|---------|
| `modules/bar/popouts/Content.qml` | Đăng ký slot popout `"kblayout"`, hiện đang mount `Fcitx5Layout` |
| `modules/bar/popouts/Fcitx5Layout.qml` | **Panel Fcitx5** (mới): danh sách các IM để chọn + hiển thị IM đang active, animation pop-in khi đổi |
| `modules/bar/popouts/kblayout/KbLayout.qml` | **Panel XKB** (cũ): danh sách XKB layouts để chọn, tooltip khi vượt quá giới hạn 4 layouts |
| `modules/bar/popouts/kblayout/KbLayoutModel.qml` | **Data model XKB**: đọc layouts từ `hyprctl getoption input:kb_layout`, parse `/usr/share/X11/xkb/rules/base.xml` để lấy tên đầy đủ, gọi `hyprctl switchxkblayout` để đổi |

---

## Cấu hình & Lock Screen

| File | Vai trò |
|------|---------|
| `modules/controlcenter/taskbar/TaskbarPane.qml` | Toggle bật/tắt icon keyboard trong bar (`showKbLayout`) trong Control Center |
| `modules/lock/Center.qml` | Hiển thị cảnh báo nếu layout bàn phím không phải mặc định khi màn hình khóa |

---

## Sơ đồ quan hệ

```
StatusIcons (bar icon)
    ├── Fcitx5.available → hiện Fcitx5.imLabel
    └── fallback → Hypr.kbLayout

Popout "kblayout"
    ├── Fcitx5Layout.qml  ← đang dùng (Fcitx5)
    │       └── Fcitx5 service
    └── KbLayout.qml      ← dự phòng (XKB)
            └── KbLayoutModel.qml → hyprctl

Config toggle: TaskbarPane → GlobalConfig.bar.status.showKbLayout
```

> **Lưu ý:** Popout `"kblayout"` hiện dùng `Fcitx5Layout` (`Content.qml:120`), nhưng `KbLayout.qml` + `KbLayoutModel.qml` vẫn tồn tại như implementation XKB độc lập — hai hệ thống song song, không dùng chung data model.
