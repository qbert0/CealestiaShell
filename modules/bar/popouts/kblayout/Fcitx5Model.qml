pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Caelestia.Config

Item {
    id: model

    property alias visibleModel: _visibleModel
    property string activeLabel: ""
    property int activeIndex: -1
    property bool loaded: false

    function start() {
        if (!loaded) {
            _getAllIMs.running = true
        } else {
            refresh()
        }
    }

    function refresh() {
        _getActiveIM.running = true
    }

    function switchTo(idx) {
        if (idx < 0 || idx >= _layoutsModel.count) return
        
        const targetIM = _layoutsModel.get(idx).token
        console.log("Switching to:", targetIM)
        
        // Cập nhật UI ngay lập tức
        const oldIndex = model.activeIndex
        model.activeIndex = idx
        model.activeLabel = _layoutsModel.get(idx).label
        _rebuildVisible()
        
        // Sau đó mới chạy process
        _switchProc.command = ["fcitx5-remote", "-s", targetIM]
        _switchProc.running = true
    }

    ListModel { id: _layoutsModel }
    ListModel { id: _visibleModel }

    Component.onCompleted: {
        start()
    }

    // Lấy tất cả IM từ config
    Process {
        id: _getAllIMs
        command: [
            "sh", 
            "-c", 
            "awk '/^\\[Groups\\/.*\\/Items\\//{found=1; next} found && /^Name=/{split($0,a,\"=\"); print a[2]; found=0}' ~/.config/fcitx5/profile"
        ]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()
                console.log("Available IMs:", output)
                
                _layoutsModel.clear()
                
                if (!output) {
                    console.log("No IMs found in config")
                    return
                }
                
                const lines = output.split('\n')
                
                for (let i = 0; i < lines.length; i++) {
                    const token = lines[i].trim()
                    if (token) {
                        _layoutsModel.append({
                            layoutIndex: i,
                            token: token,
                            label: _formatLabel(token)
                        })
                    }
                }
                
                if (_layoutsModel.count > 0) {
                    model.loaded = true
                    console.log("Loaded " + _layoutsModel.count + " IMs")
                    refresh()
                }
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                console.log("Error reading config:", text)
            }
        }
    }

    // Lấy IM đang active
    Process {
        id: _getActiveIM
        command: ["fcitx5-remote", "-n"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const currentIMToken = text.trim()
                console.log("Current IM:", currentIMToken)
                
                let foundIndex = -1
                for (let i = 0; i < _layoutsModel.count; i++) {
                    if (_layoutsModel.get(i).token === currentIMToken) {
                        foundIndex = i
                        break
                    }
                }
                
                if (foundIndex !== -1) {
                    model.activeIndex = foundIndex
                    model.activeLabel = _layoutsModel.get(foundIndex).label
                } else if (currentIMToken) {
                    console.log("Adding current IM to list:", currentIMToken)
                    _layoutsModel.append({
                        layoutIndex: _layoutsModel.count,
                        token: currentIMToken,
                        label: _formatLabel(currentIMToken)
                    })
                    model.activeIndex = _layoutsModel.count - 1
                    model.activeLabel = _formatLabel(currentIMToken)
                }
                
                _rebuildVisible()
            }
        }
    }

    // Chuyển đổi IM
    Process {
        id: _switchProc
        onRunningChanged: {
            if (!running && exitCode !== 0) {
                // Chỉ refresh nếu có lỗi để verify state thực tế
                console.log("Switch failed with exit code:", exitCode)
                refresh()
            }
            // Không refresh nếu thành công vì UI đã update rồi
        }
    }

    function _formatLabel(token) {
        const labelMap = {
            "keyboard-us": "🇺🇸 English",
            "unikey": "🇻🇳 Tiếng Việt",
            "mozc": "🇯🇵 日本語",
            "pinyin": "🇨🇳 中文 "
        }
        
        if (labelMap[token]) {
            return labelMap[token]
        }
        
        return token
            .replace(/-/g, ' ')
            .replace(/\b\w/g, c => c.toUpperCase())
    }

    function _rebuildVisible() {
        _visibleModel.clear()
        for (let i = 0; i < _layoutsModel.count; i++) {
            if (i !== model.activeIndex) {
                _visibleModel.append(_layoutsModel.get(i))
            }
        }
    }
}