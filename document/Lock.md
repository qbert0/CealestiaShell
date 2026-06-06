# Màn hình khóa (Lock Screen)

## Tổng quan

Màn hình khóa được xây dựng trên `WlSessionLock` của Wayland (giao thức `ext-session-lock-v1`), bảo vệ hoàn toàn toàn bộ session — compositor từ chối mọi thao tác render/capture bên ngoài khi đang khóa.

## Cấu trúc file

```
modules/lock/
├── Lock.qml          — Điểm vào (entry point), khởi tạo WlSessionLock + PAM + IPC
├── LockSurface.qml   — Bề mặt vẽ trên mỗi màn hình, animation vào/ra
├── Content.qml       — Layout tổng thể 3 cột của màn hình khóa
├── Center.qml        — Cột giữa: đồng hồ, ảnh đại diện, ô nhập mật khẩu
├── InputField.qml    — Trường nhập mật khẩu (hiển thị dấu chấm, có animation)
├── Pam.qml           — Xử lý xác thực PAM (passwd + fprint)
├── WeatherInfo.qml   — Widget thời tiết (cột trái, trên)
├── Fetch.qml         — System fetch info (cột trái, giữa)
├── Media.qml         — Media player control (cột trái, dưới)
├── Resources.qml     — Biểu đồ tài nguyên hệ thống (cột phải, trên)
└── NotifDock.qml     — Danh sách thông báo (cột phải, dưới)
    └── NotifGroup.qml — Nhóm thông báo theo app

assets/pam.d/
├── passwd            — Cấu hình PAM xác thực bằng mật khẩu (có pam_faillock)
└── fprint            — Cấu hình PAM xác thực bằng vân tay (pam_fprintd, max 1 lần/lần thử)

plugin/src/Caelestia/Config/
└── lockconfig.hpp    — Các tùy chọn cấu hình của lock screen

modules/
├── IdleMonitors.qml  — Kích hoạt khóa theo idle timeout / sleep / logind event
└── bar/popouts/LockStatus.qml — Popout hiển thị trạng thái CapsLock/NumLock
```

---

## Giao diện (Layout)

```
┌──────────────────────────────────────────────────────────────────┐
│  [Background: ảnh màn hình bị blur qua ScreencopyView]           │
│                                                                  │
│  ┌─────────────┐   ┌──────────────────┐   ┌──────────────────┐  │
│  │ WeatherInfo │   │   [Đồng hồ HH:MM]│   │   Resources      │  │
│  │─────────────│   │   [Ngày tháng]   │   │  CPU  │  Temp    │  │
│  │   Fetch     │   │   [Avatar]       │   │  RAM  │  Storage │  │
│  │  (sysinfo)  │   │  [Password box]  │   │──────────────────│  │
│  │─────────────│   │  [Error/msg]     │   │   NotifDock      │  │
│  │   Media     │   │                  │   │  (Thông báo)     │  │
│  │  (player)   │   │                  │   │                  │  │
│  └─────────────┘   └──────────────────┘   └──────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

Layout được triển khai qua `RowLayout` trong [Content.qml](../modules/lock/Content.qml), gồm 3 cột với `Layout.fillWidth: true`.

---

## Các thành phần giao diện

### 1. Background — Nền bị mờ

**File:** [LockSurface.qml:159–174](../modules/lock/LockSurface.qml#L159)

- Dùng `ScreencopyView` để chụp ảnh màn hình thực tế ngay trước khi khóa.
- Áp dụng `MultiEffect` (blur max=64) để làm mờ nền.
- Opacity ban đầu là `0`, fade-in bằng animation khi màn hình khóa xuất hiện.
- **Workaround quan trọng:** [Lock.qml:29–41](../modules/lock/Lock.qml#L29) — Load trước một `ScreencopyView` giả ngay lúc shell khởi động để ICC backend kịp khởi tạo; nếu không, lần chụp đầu tiên (khi đang khóa) sẽ thất bại vì compositor từ chối screencopy khi đã khóa.

### 2. Animation khóa / mở khóa

**File:** [LockSurface.qml](../modules/lock/LockSurface.qml)

**Khi khóa (initAnim):**
1. Background fade in.
2. `lockContent` (card chứa biểu tượng khóa) scale từ 0→1, xoay 360°.
3. Biểu tượng lock (`lock` icon) rotate rồi fade out.
4. Content thực sự (3 cột) fade in + scale vào.
5. Card nở rộng từ kích thước icon → kích thước màn hình khóa đầy đủ.

**Khi mở khóa (unlockAnim):**
1. Content thu nhỏ về 0 + fade out.
2. Biểu tượng lock hiện trở lại.
3. Card thu nhỏ về kích thước icon.
4. Background fade out.
5. Đặt `lock.locked = false` → Wayland giải phóng session lock.

### 3. Center — Cột giữa

**File:** [Center.qml](../modules/lock/Center.qml)

| Phần tử | Mô tả |
|---|---|
| Đồng hồ | Giờ và phút dạng lớn (`extraLarge * 3`), font clock, màu primary/secondary. Hỗ trợ 12h/24h qua `GlobalConfig.services.useTwelveHourClock`. |
| Ngày tháng | `dddd, d MMMM yyyy` bằng font mono, màu tertiary. |
| Avatar | Ảnh từ `~/.face`; nếu không có, hiện icon `person`. |
| Ô mật khẩu | `InputField` + nút gửi (arrow_forward) + icon fingerprint/lock. |
| Thông báo trạng thái | CapsLock, NumLock, keyboard layout (từ `Hypr`). |
| Thông báo lỗi | Lỗi mật khẩu/vân tay với animation flash. |

**Ô nhập mật khẩu:**
- Khi có ký tự trong buffer: ẩn placeholder, hiện dấu chấm (animated).
- Nút submit sáng primary khi có nội dung, xám khi rỗng.
- Icon bên trái chuyển đổi: `fingerprint` (đang quét) → `fingerprint_off` (hết lượt) → `lock` (đang xác thực passwd).
- `CircularIndicator` quay khi đang xác thực.

### 4. InputField — Trường mật khẩu

**File:** [InputField.qml](../modules/lock/InputField.qml)

- Mỗi ký tự trong buffer được render thành một hình chữ nhật nhỏ (`StyledRect`) — không bao giờ hiển thị ký tự thực.
- Thêm ký tự: scale + opacity animate từ 0→1.
- Xóa ký tự: animate thu nhỏ rồi mới remove khỏi ListView.
- Placeholder: `"Enter your password"` / `"Loading..."` / `"Maximum tries"` tùy trạng thái PAM.

### 5. WeatherInfo — Thời tiết

**File:** [WeatherInfo.qml](../modules/lock/WeatherInfo.qml)

- Icon thời tiết (Material icon), mô tả, độ ẩm, nhiệt độ hiện tại, cảm giác như.
- Dự báo theo giờ (3–5 slot) hiện khi `rootHeight > 820`.
- Tiêu đề "Weather" hiện khi `rootHeight > 610`.
- Tự động reload mỗi 15 phút.
- Hỗ trợ °C / °F qua `GlobalConfig.services.useFahrenheit`.

### 6. Fetch — Thông tin hệ thống

**File:** [Fetch.qml](../modules/lock/Fetch.qml)

Hiển thị kiểu `neofetch/fastfetch`:

```
> caelestiafetch.sh               [distro logo]
OS  : Arch Linux
WM  : Hyprland
USER: username
UP  : 2h 30m
BATT: (+) 85%          ← chỉ hiện nếu là laptop
[■ ■ ■ ■ ■ ■ ■ ■]      ← 8 màu terminal palette
```

- Logo distro từ `SysInfo.osLogo`; nếu là logo mặc định Caelestia, dùng `Logo` component.
- `Config.lock.recolourLogo = true` → tô màu logo theo theme.

### 7. Media — Điều khiển nhạc

**File:** [Media.qml](../modules/lock/Media.qml)

- Hiển thị ảnh bìa album (album art) làm background với gradient fade từ trái sang phải.
- Tên nghệ sĩ, tên bài hát từ `Players.active`.
- 3 nút: Previous / Play-Pause / Next.
- Nút Play-Pause: active state → màu Primary, radius vuông; inactive → màu container, radius tròn.

### 8. Resources — Tài nguyên hệ thống

**File:** [Resources.qml](../modules/lock/Resources.qml)

4 biểu đồ tròn (`CircularProgress`) trong grid 2×2:

| Icon | Chỉ số | Màu |
|---|---|---|
| `memory` | CPU % | Primary |
| `thermostat` | CPU temp (0–90°C) | Secondary |
| `memory_alt` | RAM % | Secondary |
| `hard_disk` | Storage % | Tertiary |

### 9. NotifDock — Thông báo

**File:** [NotifDock.qml](../modules/lock/NotifDock.qml), [NotifGroup.qml](../modules/lock/NotifGroup.qml)

- Hiển thị thông báo nhóm theo app name.
- `Config.lock.hideNotifs = true` → ẩn toàn bộ, hiện "Unlock for Notifications".
- Mỗi nhóm (`NotifGroup`):
  - Icon app hoặc ảnh notification, badge nếu có cả hai.
  - Urgency: `critical` → màu secondaryContainer/error; `normal` → màu container; `low` → màu surfaceContainerHigh.
  - Nút expand khi có nhiều hơn `Config.notifs.groupPreviewNum` thông báo.
  - Animation thêm/xóa/di chuyển thông báo.

---

## Xác thực (PAM)

**File:** [Pam.qml](../modules/lock/Pam.qml)

### Luồng mật khẩu (passwd)

```
User nhập phím → handleKey() → buffer tích lũy
Enter / nút → passwd.start() (PamContext "passwd")
                  ↓
           pam_faillock preauth
           pam_unix (xác thực Unix password)
           pam_faillock authfail/authsucc
                  ↓
      PamResult.Success → lock.unlock()
      PamResult.Failed  → state = "fail", flash error msg, reset sau 4s
      PamResult.Error   → state = "error"
      PamResult.MaxTries→ state = "max" (vĩnh viễn đến khi mở khóa)
```

**Xử lý phím đặc biệt:**
- `Enter` / `Return` → submit
- `Backspace` → xóa 1 ký tự
- `Ctrl+Backspace` → xóa toàn bộ buffer
- Ký tự điều khiển (0x00–0x1F, 0x7F–0x9F) bị lọc

**Cấu hình pam.d/passwd:** Dùng `pam_faillock` để đếm và khóa tài khoản sau nhiều lần thất bại. Khi tài khoản bị khóa bởi faillock, `lockMessage` hiển thị thông báo và thời gian còn lại.

### Luồng vân tay (fprint)

```
Khi lock.secure = true:
  fprintd-list $USER → kiểm tra vân tay có sẵn
  → fprint.start() (PamContext "fprint")
        ↓
  pam_fprintd (max-tries=1 mỗi lần gọi)
        ↓
  PamResult.Success   → lock.unlock()
  PamResult.MaxTries  → tries++
    tries < maxFprintTries → fprintState = "fail", restart
    tries >= maxFprintTries → fprintState = "max", abort (không thử thêm)
  PamResult.Error     → errorTries++, retry sau 800ms (tối đa 5 lần)
```

**Cấu hình:**
- `GlobalConfig.lock.enableFprint` — bật/tắt vân tay
- `GlobalConfig.lock.maxFprintTries` — số lần thử tối đa (mặc định 3)

**Thông báo lỗi theo tình huống:**

| Tình huống | Thông báo |
|---|---|
| Sai mật khẩu | "Incorrect password. Please try again." |
| Sai mật khẩu, có vân tay | "Incorrect password. Please try again or use fingerprint." |
| Hết lượt mật khẩu | "Maximum password attempts reached." |
| Hết lượt vân tay | "Maximum fingerprint attempts reached. Please use password." |
| Hết cả hai | "Maximum password and fingerprint attempts reached." |
| Vân tay không nhận | "Fingerprint not recognized (n/max). Please try again or use password." |
| Lỗi PAM vân tay | "FP ERROR: \<message\>" |
| Lỗi PAM mật khẩu | "PW ERROR: \<message\>" |

---

## Kích hoạt khóa (Triggers)

**File:** [IdleMonitors.qml](../modules/IdleMonitors.qml), [Lock.qml](../modules/lock/Lock.qml)

| Nguồn | Cơ chế |
|---|---|
| Idle timeout | `IdleMonitor` với `timeout` từ `GlobalConfig.general.idle.timeouts`; action có thể là `"lock"`, lệnh Hyprland, hoặc command tùy chỉnh |
| Trước khi sleep | `LogindManager.onAboutToSleep` → khóa nếu `GlobalConfig.general.idle.lockBeforeSleep = true` |
| Logind lock/unlock | `LogindManager.onLockRequested` / `onUnlockRequested` (ví dụ: `loginctl lock-session`) |
| IPC | `qs ipc call lock lock` / `qs ipc call lock unlock` / `qs ipc call lock isLocked` |
| Shortcut | CustomShortcut `"lock"` và `"unlock"` (đăng ký với Hyprland) |
| Audio guard | Không kích hoạt idle nếu đang phát nhạc (`inhibitWhenAudio = true` + `Players.list.some(p => p.isPlaying)`) |

**Sau khi mở khóa qua logind:** Tự động kiểm tra file `/tmp/qs-restart-needed` — nếu tồn tại, restart shell sau 2 giây (dùng cho hot-reload khi shell update trong lúc khóa máy).

---

## Cấu hình (LockConfig)

**File:** [plugin/src/Caelestia/Config/lockconfig.hpp](../plugin/src/Caelestia/Config/lockconfig.hpp)

| Thuộc tính | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `recolourLogo` | bool | `false` | Tô màu logo distro theo màu theme primary |
| `enableFprint` | bool | `true` | Bật xác thực vân tay (global) |
| `maxFprintTries` | int | `3` | Số lần thử vân tay tối đa |
| `hideNotifs` | bool | `false` | Ẩn thông báo khi màn hình đang khóa |

---

## Đa màn hình (Multi-monitor)

`LockSurface` là `WlSessionLockSurface` — Quickshell tự tạo một instance trên **mỗi màn hình** (`screen` property). Mỗi surface có token riêng (`Config.screen`, `Tokens.screen`) để scale theo chiều cao màn hình đó.

Kích thước card trung tâm:

```
width  = screen.height × Tokens.sizes.lock.heightMult × Tokens.sizes.lock.ratio
height = screen.height × Tokens.sizes.lock.heightMult
```

Scale cột giữa: `Math.min(1, screen.height / 1440)` — thiết kế chuẩn cho 1440p, tự co nhỏ với màn hình nhỏ hơn.
