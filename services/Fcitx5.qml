pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string activeLabel: ""
    property string shortLabel: "??"
    property int activeIndex: -1
    property bool loaded: false

    readonly property alias visibleModel: _visibleModel

    function start() {
        if (!loaded) {
            _getAllIMs.running = true;
        } else {
            refresh();
        }
    }

    function refresh() {
        _getActiveIM.running = true;
    }

    function cycleNext() {
        if (_layoutsModel.count === 0) return;
        switchTo((root.activeIndex + 1) % _layoutsModel.count);
    }

    function switchTo(idx: int) {
        if (idx < 0 || idx >= _layoutsModel.count) return;

        const targetIM = _layoutsModel.get(idx).token;
        root.activeIndex = idx;
        root.activeLabel = _layoutsModel.get(idx).label;
        root.shortLabel = _layoutsModel.get(idx).short;
        _rebuildVisible();

        _switchProc.command = ["fcitx5-remote", "-s", targetIM];
        _switchProc.running = true;
    }

    function _formatLabel(token: string): string {
        const labelMap = {
            "keyboard-us": "🇺🇸 English",
            "unikey": "🇻🇳 Tiếng Việt",
            "mozc": "🇯🇵 日本語",
            "pinyin": "🇨🇳 中文"
        };
        if (labelMap[token]) return labelMap[token];
        return token.replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    }

    function _shortLabel(token: string): string {
        const shortMap = {
            "keyboard-us": "en",
            "unikey": "vi",
            "mozc": "jp",
            "pinyin": "zh"
        };
        if (shortMap[token]) return shortMap[token];
        return token.split("-").pop().substring(0, 2);
    }

    function _rebuildVisible() {
        _visibleModel.clear();
        for (let i = 0; i < _layoutsModel.count; i++) {
            if (i !== root.activeIndex) {
                _visibleModel.append(_layoutsModel.get(i));
            }
        }
    }

    Component.onCompleted: start()

    ListModel { id: _layoutsModel }
    ListModel { id: _visibleModel }

    Process {
        id: _getAllIMs
        command: [
            "sh", "-c",
            "awk '/^\\[Groups\\/.*\\/Items\\//{found=1; next} found && /^Name=/{split($0,a,\"=\"); print a[2]; found=0}' ~/.config/fcitx5/profile"
        ]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                _layoutsModel.clear();
                if (!output) return;

                const lines = output.split('\n');
                for (let i = 0; i < lines.length; i++) {
                    const token = lines[i].trim();
                    if (token) {
                        _layoutsModel.append({
                            layoutIndex: i,
                            token: token,
                            label: root._formatLabel(token),
                            short: root._shortLabel(token)
                        });
                    }
                }

                if (_layoutsModel.count > 0) {
                    root.loaded = true;
                    root.refresh();
                }
            }
        }
    }

    Process {
        id: _getActiveIM
        command: ["fcitx5-remote", "-n"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const currentIMToken = text.trim();
                if (!currentIMToken) return;

                let foundIndex = -1;
                for (let i = 0; i < _layoutsModel.count; i++) {
                    if (_layoutsModel.get(i).token === currentIMToken) {
                        foundIndex = i;
                        break;
                    }
                }

                if (foundIndex === -1) {
                    _layoutsModel.append({
                        layoutIndex: _layoutsModel.count,
                        token: currentIMToken,
                        label: root._formatLabel(currentIMToken),
                        short: root._shortLabel(currentIMToken)
                    });
                    foundIndex = _layoutsModel.count - 1;
                }

                if (foundIndex === root.activeIndex) return;

                root.activeIndex = foundIndex;
                root.activeLabel = _layoutsModel.get(foundIndex).label;
                root.shortLabel = _layoutsModel.get(foundIndex).short;
                root._rebuildVisible();
            }
        }
    }

    Process {
        id: _switchProc
        onRunningChanged: {
            if (!running && exitCode !== 0) {
                root.refresh();
            }
        }
    }
}
