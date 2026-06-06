# Bug History — Background Module (`modules/background/`)

> File này ghi lại chuỗi lỗi theo thứ tự thời gian trong nhóm module background.  
> Mỗi entry có: triệu chứng, nguyên nhân gốc rễ, fix áp dụng, và trạng thái.  
> Mục đích: đối chiếu khi có regression hoặc thêm feature mới vào vùng này.

---

## [BG-1] Canvas Drag Constraint Asymmetry — CanvasSection.qml

| Thuộc tính | Giá trị |
|-----------|---------|
| **Ngày phát hiện** | 2026-06-05 |
| **File** | `modules/controlcenter/display/CanvasSection.qml` |
| **Trạng thái** | ✅ ĐÃ SỬA |
| **Lớp lỗi** | UI geometry — padding không đối xứng |

### Triệu chứng

Trong **Display Pane**, vùng canvas sắp xếp màn hình (dot-grid + monitor cards) bị thu hẹp và lùi vào bên phải so với kỳ vọng. Nhìn trực quan: phần lưới chấm nền (canvas background) không sát mép trái của card, xuất hiện dải trắng/nền rõ ở bên trái.

### Nguyên nhân gốc rễ

`DisplayPane.qml` wrap `CanvasSection` trong `SectionContainer`. Padding được áp dụng **hai lần**:

| Layer | Nguồn | Giá trị |
|-------|-------|---------|
| Loader content margin | `DisplayPane.qml` | `Tokens.padding.large` |
| SectionContainer internal ColumnLayout | `SectionContainer.qml` | `Tokens.padding.large` |
| **Tổng cộng** | | **`2 × Tokens.padding.large`** |

Các pane khác (AudioPane, NetworkPane...) cũng có double-padding này, nhưng content của chúng là form controls (SwitchRow, Slider…) nên không thấy rõ. `CanvasSection` là vùng đồ họa full-width nên double-padding trở nên rõ ràng.

Hệ quả thứ yếu: drag constraint dùng `root.width - 12` thay vì `root.width - 24`, khiến card có thể kéo ra khỏi mép phải trong khi mép trái luôn có margin 12px → bất đối xứng.

```diff
// CanvasSection.qml onPositionChanged
- const maxX = Math.max(0, (root.width  - 12 - mon.cw) / zoom)
- const maxY = Math.max(0, (root.height - 12 - mon.ch) / zoom)
+ const maxX = Math.max(0, (root.width  - 24 - mon.cw) / zoom)
+ const maxY = Math.max(0, (root.height - 24 - mon.ch) / zoom)
```

### Fix áp dụng

- `modules/controlcenter/display/CanvasSection.qml` dòng 162–163: đổi `-12` → `-24` trong drag constraint maxX/maxY
- `components/SectionContainer.qml`: thêm `property real contentPadding` để có thể override
- `modules/controlcenter/display/DisplayPane.qml`: set `contentPadding: 0` cho SectionContainer bọc CanvasSection

**Kết quả**: Canvas có đúng 12px margin đều hai bên. Card không thể kéo ra khỏi biên.

---

## [BG-2] Visualiser Offset Null Crash — Visualiser.qml

| Thuộc tính | Giá trị |
|-----------|---------|
| **Ngày phát hiện** | 2026-06-05 (instance `b4iggr5gt`, 20:32:11) |
| **File** | `modules/background/Visualiser.qml` |
| **Trạng thái** | ✅ ĐÃ SỬA |
| **Lớp lỗi** | Runtime null access — monitor unplug event |

### Triệu chứng

```
2026-06-05 20:32:11  WARN: @modules/background/Visualiser.qml[19:-1]:
  TypeError: Cannot read property 'height' of null
```

Lỗi xuất hiện **đồng thời** cùng một batch các lỗi null khác:

```
@modules/bar/BarWrapper.qml[18:-1]:  TypeError: Cannot read property 'name' of null
@modules/bar/components/Brightness.qml[168:-1]: TypeError: Cannot read ...
@modules/bar/components/workspaces/Workspaces.qml[18:-1]: TypeError: Cannot read ...
@modules/launcher/Wrapper.qml[19:-1]: TypeError: Cannot read property 'height' of null
```

→ Pattern: tất cả lỗi trong cùng 1ms, trên các file khác nhau. Đây là dấu hiệu **event monitor disconnect từ Hyprland**.

### Nguyên nhân gốc rễ

**Chain sự kiện khi tháo màn hình:**

```
Hyprland xoá monitor khỏi danh sách
  → Quickshell cập nhật Screens.screens
  → Variants delegates có modelData = screen bị xoá bắt đầu destroy
  → Trong quá trình destroy, property bindings còn được evaluate 1 lần cuối
  → screen = null (hoặc object trong trạng thái transitional)
  → screen.height → TypeError
```

Dòng lỗi cụ thể — `Visualiser.qml:19`:

```qml
// TRƯỚC FIX — không có null guard
property real offset: shouldBeActive ? 0 : screen.height * 0.2
```

Khi `shouldBeActive = false` (cava tắt hoặc có cửa sổ), binding phải evaluate `screen.height`. Nếu `screen` là null trong chu kỳ destroy → crash.

Lưu ý: dòng 18 (`shouldBeActive`) đã có `?.` guard (`Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values`), nhưng `screen` bản thân nó không được guard.

### Fix áp dụng

```diff
// modules/background/Visualiser.qml:19
- property real offset: shouldBeActive ? 0 : screen.height * 0.2
+ property real offset: shouldBeActive ? 0 : (screen?.height ?? 0) * 0.2
```

**Logic**: Nếu `screen` là null → fallback về `0` → `offset = 0` (tương đương `shouldBeActive = true` state, không trượt lên). Đây là hành vi an toàn — widget chỉ đang destroy nên visual không quan trọng.

### Scope của lỗi cùng loại (CHƯA SỬA trong các module khác)

Cùng pattern null access khi monitor disconnect còn tồn tại ở:

| File | Dòng | Property bị null |
|------|------|-----------------|
| `modules/bar/BarWrapper.qml` | 18 | `screen.name` |
| `modules/launcher/Wrapper.qml` | 19 | `screen.height` |
| `modules/bar/components/workspaces/Workspaces.qml` | 18 | monitor object |

Các lỗi này chỉ là warning trong log, không gây crash hay mất dữ liệu. Shell tiếp tục hoạt động bình thường sau khi hoàn tất destroy. Tuy nhiên nếu muốn log sạch, cần thêm `?.` guard tương tự.

### Files thay đổi

| File | Dòng | Thay đổi |
|------|------|---------|
| `modules/background/Visualiser.qml` | 19 | `screen.height` → `(screen?.height ?? 0)` |

---

## Ghi chú kiến trúc — Background module

- `Background.qml` dùng `Variants` với model là `Screens.screens` → mỗi màn hình có 1 instance riêng
- Mỗi `Visualiser` nhận `screen: ShellScreen` làm required property
- Khi Quickshell xoá screen khỏi model, delegate bị destroy nhưng QML binding engine vẫn có thể evaluate property bindings 1 lần trong quá trình cleanup
- `pragma ComponentBehavior: Bound` không ngăn pattern này — nó chỉ enforce variable binding scope, không thêm null safety
- Pattern an toàn: dùng `?.` và `?? default` cho **tất cả** property access trên `screen` trong delegates của Variants model

