pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Item {
    id: root

    required property var monitor

    signal monitorPropertyChanged(string propertyName, var value)

    implicitHeight: content.implicitHeight

    function modeText(width: int, height: int, refresh: int): string {
        return String(width) + "x" + String(height) + " @" + String(refresh) + "Hz";
    }

    function transformText(transform: string): string {
        switch (transform) {
            case "90": return "90°";
            case "180": return "180°";
            case "270": return "270°";
            case "flipped": return qsTr("Flipped");
            case "flipped-90": return "Flipped 90°";
            case "flipped-180": return "Flipped 180°";
            case "flipped-270": return "Flipped 270°";
            default: return qsTr("Normal");
        }
    }

    function syncTransformSelector(): void {
        if (root.monitor === null) {
            transformSelector.active = transformNormalItem;
            return;
        }

        switch (root.monitor.transform) {
            case "90":
                transformSelector.active = transform90Item;
                break;
            case "180":
                transformSelector.active = transform180Item;
                break;
            case "270":
                transformSelector.active = transform270Item;
                break;
            case "flipped":
                transformSelector.active = transformFlippedItem;
                break;
            case "flipped-90":
                transformSelector.active = transformFlipped90Item;
                break;
            case "flipped-180":
                transformSelector.active = transformFlipped180Item;
                break;
            case "flipped-270":
                transformSelector.active = transformFlipped270Item;
                break;
            default:
                transformSelector.active = transformNormalItem;
        }
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.normal

        SectionContainer {
            Layout.fillWidth: true
            visible: root.monitor === null

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Click on a monitor in the canvas to configure")
                font.pointSize: Tokens.font.size.normal
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.monitor !== null
            spacing: Tokens.spacing.normal

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: root.monitor !== null ? root.monitor.name : ""
                    font.pointSize: Tokens.font.size.titleMedium
                    font.weight: 500
                }

                StyledText {
                    text: root.monitor !== null ? String(root.monitor.width) + "x" + String(root.monitor.height) : ""
                    font.pointSize: Tokens.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            SectionContainer {
                Layout.fillWidth: true

                StyledText {
                    text: qsTr("Position & Layout")
                    font.pointSize: Tokens.font.size.normal
                    font.weight: 500
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Tokens.spacing.normal
                    rowSpacing: Tokens.spacing.normal

                    SpinBoxRow {
                        label: qsTr("Position X")
                        value: root.monitor !== null ? root.monitor.x : 0
                        min: -10000
                        max: 10000
                        step: 10
                        onValueModified: value => root.monitorPropertyChanged("x", value)
                    }

                    SpinBoxRow {
                        label: qsTr("Position Y")
                        value: root.monitor !== null ? root.monitor.y : 0
                        min: -10000
                        max: 10000
                        step: 10
                        onValueModified: value => root.monitorPropertyChanged("y", value)
                    }

                    SpinBoxRow {
                        label: qsTr("Scale")
                        value: root.monitor !== null ? root.monitor.scale : 1
                        min: 0.25
                        max: 3
                        step: 0.25
                        onValueModified: value => root.monitorPropertyChanged("scale", value)
                    }

                    SplitButtonRow {
                        id: transformSelector

                        label: qsTr("Transform")
                        menuItems: [
                            transformNormalItem,
                            transform90Item,
                            transform180Item,
                            transform270Item,
                            transformFlippedItem,
                            transformFlipped90Item,
                            transformFlipped180Item,
                            transformFlipped270Item
                        ]

                        Component.onCompleted: root.syncTransformSelector()

                        Connections {
                            target: root

                            function onMonitorChanged(): void {
                                root.syncTransformSelector();
                            }
                        }

                        MenuItem {
                            id: transformNormalItem

                            text: qsTr("Normal")
                            icon: "screen_rotation"
                            activeText: qsTr("Normal")
                            onClicked: {
                                root.monitorPropertyChanged("transform", "normal");
                                transformSelector.active = transformNormalItem;
                            }
                        }

                        MenuItem {
                            id: transform90Item

                            text: "90°"
                            icon: "screen_rotation"
                            activeText: "90°"
                            onClicked: {
                                root.monitorPropertyChanged("transform", "90");
                                transformSelector.active = transform90Item;
                            }
                        }

                        MenuItem {
                            id: transform180Item

                            text: "180°"
                            icon: "screen_rotation"
                            activeText: "180°"
                            onClicked: {
                                root.monitorPropertyChanged("transform", "180");
                                transformSelector.active = transform180Item;
                            }
                        }

                        MenuItem {
                            id: transform270Item

                            text: "270°"
                            icon: "screen_rotation"
                            activeText: "270°"
                            onClicked: {
                                root.monitorPropertyChanged("transform", "270");
                                transformSelector.active = transform270Item;
                            }
                        }

                        MenuItem {
                            id: transformFlippedItem

                            text: qsTr("Flipped")
                            icon: "flip"
                            activeText: qsTr("Flipped")
                            onClicked: {
                                root.monitorPropertyChanged("transform", "flipped");
                                transformSelector.active = transformFlippedItem;
                            }
                        }

                        MenuItem {
                            id: transformFlipped90Item

                            text: "Flipped 90°"
                            icon: "flip"
                            activeText: "Flipped 90°"
                            onClicked: {
                                root.monitorPropertyChanged("transform", "flipped-90");
                                transformSelector.active = transformFlipped90Item;
                            }
                        }

                        MenuItem {
                            id: transformFlipped180Item

                            text: "Flipped 180°"
                            icon: "flip"
                            activeText: "Flipped 180°"
                            onClicked: {
                                root.monitorPropertyChanged("transform", "flipped-180");
                                transformSelector.active = transformFlipped180Item;
                            }
                        }

                        MenuItem {
                            id: transformFlipped270Item

                            text: "Flipped 270°"
                            icon: "flip"
                            activeText: "Flipped 270°"
                            onClicked: {
                                root.monitorPropertyChanged("transform", "flipped-270");
                                transformSelector.active = transformFlipped270Item;
                            }
                        }
                    }
                }
            }

            SectionContainer {
                Layout.fillWidth: true

                StyledText {
                    text: qsTr("Resolution & Refresh")
                    font.pointSize: Tokens.font.size.normal
                    font.weight: 500
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Tokens.spacing.normal
                    rowSpacing: Tokens.spacing.normal

                    SplitButtonRow {
                        id: modeSelector

                        label: qsTr("Mode")
                        menuItems: [
                            mode1024x768Item,
                            mode1280x720Item,
                            mode1366x768Item,
                            mode1360x768Item,
                            mode1440x900Item,
                            mode1600x900Item,
                            mode1680x1050Item,
                            mode1920x1080_50Item,
                            mode1920x1080_60Item,
                            mode1920x1200Item
                        ]

                        MenuItem {
                            id: mode1024x768Item

                            text: "1024x768 @60Hz (4:3)"
                            icon: "monitor"
                            activeText: "1024x768 @60Hz"
                            onClicked: {
                                modeSelector.active = mode1024x768Item;
                                root.monitorPropertyChanged("width", 1024);
                                root.monitorPropertyChanged("height", 768);
                                root.monitorPropertyChanged("refresh", 60);
                            }
                        }

                        MenuItem {
                            id: mode1280x720Item

                            text: "1280x720 @60Hz (16:9)"
                            icon: "monitor"
                            activeText: "1280x720 @60Hz"
                            onClicked: {
                                modeSelector.active = mode1280x720Item;
                                root.monitorPropertyChanged("width", 1280);
                                root.monitorPropertyChanged("height", 720);
                                root.monitorPropertyChanged("refresh", 60);
                            }
                        }

                        MenuItem {
                            id: mode1366x768Item

                            text: "1366x768 @60Hz (16:9)"
                            icon: "monitor"
                            activeText: "1366x768 @60Hz"
                            onClicked: {
                                modeSelector.active = mode1366x768Item;
                                root.monitorPropertyChanged("width", 1366);
                                root.monitorPropertyChanged("height", 768);
                                root.monitorPropertyChanged("refresh", 60);
                            }
                        }

                        MenuItem {
                            id: mode1360x768Item

                            text: "1360x768 @60Hz (16:9)"
                            icon: "monitor"
                            activeText: "1360x768 @60Hz"
                            onClicked: {
                                modeSelector.active = mode1360x768Item;
                                root.monitorPropertyChanged("width", 1360);
                                root.monitorPropertyChanged("height", 768);
                                root.monitorPropertyChanged("refresh", 60);
                            }
                        }

                        MenuItem {
                            id: mode1440x900Item

                            text: "1440x900 @60Hz (16:10)"
                            icon: "monitor"
                            activeText: "1440x900 @60Hz"
                            onClicked: {
                                modeSelector.active = mode1440x900Item;
                                root.monitorPropertyChanged("width", 1440);
                                root.monitorPropertyChanged("height", 900);
                                root.monitorPropertyChanged("refresh", 60);
                            }
                        }

                        MenuItem {
                            id: mode1600x900Item

                            text: "1600x900 @60Hz (16:9)"
                            icon: "monitor"
                            activeText: "1600x900 @60Hz"
                            onClicked: {
                                modeSelector.active = mode1600x900Item;
                                root.monitorPropertyChanged("width", 1600);
                                root.monitorPropertyChanged("height", 900);
                                root.monitorPropertyChanged("refresh", 60);
                            }
                        }

                        MenuItem {
                            id: mode1680x1050Item

                            text: "1680x1050 @60Hz (16:10)"
                            icon: "monitor"
                            activeText: "1680x1050 @60Hz"
                            onClicked: {
                                modeSelector.active = mode1680x1050Item;
                                root.monitorPropertyChanged("width", 1680);
                                root.monitorPropertyChanged("height", 1050);
                                root.monitorPropertyChanged("refresh", 60);
                            }
                        }

                        MenuItem {
                            id: mode1920x1080_50Item

                            text: "1920x1080 @50Hz (16:9)"
                            icon: "monitor"
                            activeText: "1920x1080 @50Hz"
                            onClicked: {
                                modeSelector.active = mode1920x1080_50Item;
                                root.monitorPropertyChanged("width", 1920);
                                root.monitorPropertyChanged("height", 1080);
                                root.monitorPropertyChanged("refresh", 50);
                            }
                        }

                        MenuItem {
                            id: mode1920x1080_60Item

                            text: "1920x1080 @60Hz (16:9)"
                            icon: "monitor"
                            activeText: "1920x1080 @60Hz"
                            onClicked: {
                                modeSelector.active = mode1920x1080_60Item;
                                root.monitorPropertyChanged("width", 1920);
                                root.monitorPropertyChanged("height", 1080);
                                root.monitorPropertyChanged("refresh", 60);
                            }
                        }

                        MenuItem {
                            id: mode1920x1200Item

                            text: "1920x1200 @60Hz (16:10)"
                            icon: "monitor"
                            activeText: "1920x1200 @60Hz"
                            onClicked: {
                                modeSelector.active = mode1920x1200Item;
                                root.monitorPropertyChanged("width", 1920);
                                root.monitorPropertyChanged("height", 1200);
                                root.monitorPropertyChanged("refresh", 60);
                            }
                        }
                    }

                    SpinBoxRow {
                        label: qsTr("Custom width")
                        value: root.monitor !== null ? root.monitor.width : 1920
                        min: 640
                        max: 7680
                        step: 10
                        onValueModified: value => root.monitorPropertyChanged("width", value)
                    }

                    SpinBoxRow {
                        label: qsTr("Custom height")
                        value: root.monitor !== null ? root.monitor.height : 1080
                        min: 480
                        max: 4320
                        step: 10
                        onValueModified: value => root.monitorPropertyChanged("height", value)
                    }

                    SpinBoxRow {
                        label: qsTr("Refresh rate")
                        value: root.monitor !== null && root.monitor.refresh !== undefined ? root.monitor.refresh : 60
                        min: 24
                        max: 480
                        step: 1
                        onValueModified: value => root.monitorPropertyChanged("refresh", value)
                    }
                }
            }

            SectionContainer {
                Layout.fillWidth: true

                StyledText {
                    text: qsTr("Advanced")
                    font.pointSize: Tokens.font.size.normal
                    font.weight: 500
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Tokens.spacing.normal
                    rowSpacing: Tokens.spacing.normal

                    SwitchRow {
                        label: qsTr("DPMS")
                        checked: root.monitor !== null ? root.monitor.dpms : true
                        onToggled: checked => root.monitorPropertyChanged("dpms", checked)
                    }

                    SwitchRow {
                        label: qsTr("Adaptive Sync")
                        checked: root.monitor !== null ? root.monitor.vrr : false
                        onToggled: checked => root.monitorPropertyChanged("vrr", checked)
                    }

                    SwitchRow {
                        label: qsTr("10-bit color")
                        checked: root.monitor !== null && root.monitor.bit10 !== undefined ? root.monitor.bit10 : false
                        onToggled: checked => root.monitorPropertyChanged("bit10", checked)
                    }

                    SplitButtonRow {
                        id: mirrorSelector

                        label: qsTr("Mirror from")
                        menuItems: [mirrorNoneItem, mirrorEdpItem, mirrorDpItem]

                        MenuItem {
                            id: mirrorNoneItem

                            text: qsTr("None")
                            icon: "splitscreen"
                            activeText: qsTr("None")
                            onClicked: {
                                mirrorSelector.active = mirrorNoneItem;
                                root.monitorPropertyChanged("mirrorFrom", "");
                            }
                        }

                        MenuItem {
                            id: mirrorEdpItem

                            text: "eDP-1"
                            icon: "monitor"
                            activeText: "eDP-1"
                            onClicked: {
                                mirrorSelector.active = mirrorEdpItem;
                                root.monitorPropertyChanged("mirrorFrom", "eDP-1");
                            }
                        }

                        MenuItem {
                            id: mirrorDpItem

                            text: "DP-1"
                            icon: "monitor"
                            activeText: "DP-1"
                            onClicked: {
                                mirrorSelector.active = mirrorDpItem;
                                root.monitorPropertyChanged("mirrorFrom", "DP-1");
                            }
                        }
                    }
                }
            }

            SectionContainer {
                Layout.fillWidth: true

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.normal

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: qsTr("kanshi config: ~/.config/kanshi/config")
                            font.pointSize: Tokens.font.size.small
                            font.family: "Monospace"
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            text: qsTr("Changes will be applied when you click Apply or Save")
                            font.pointSize: Tokens.font.size.small
                            color: Colours.palette.m3primary
                        }
                    }

                    IconTextButton {
                        icon: "open_in_new"
                        text: qsTr("Wiki")
                        type: IconTextButton.Tonal
                        onClicked: Qt.openUrlExternally("https://github.com/your-repo/display-config")
                    }
                }
            }
        }
    }
}