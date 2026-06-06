import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

StyledRect {
    id: root

    required property var monitors
    required property int selectedIndex

    signal monitorMoved(int index, int newX, int newY)
    signal monitorSelected(int index)

    color: Colours.palette.m3surfaceContainerHighest
    radius: Tokens.rounding.medium
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outline, 0.2)

    clip: true

    function monitorX(monitor) {
        return Math.max(0, monitor.x / 10 + 50);
    }

    function monitorY(monitor) {
        return Math.max(0, monitor.y / 10 + 50);
    }

    function positionText(monitor) {
        return String(monitor.x) + "," + String(monitor.y);
    }

    Item {
        id: canvasContent

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium

        Repeater {
            model: root.monitors

            delegate: Item {
                id: monitorItem

                required property int index
                required property var modelData

                readonly property bool selected: root.selectedIndex === index
                readonly property int monitorWidth: Math.max(80, Math.round(modelData.width / 1920 * 120))
                readonly property int monitorHeight: Math.max(60, Math.round(modelData.height / 1080 * 90))

                x: root.monitorX(modelData)
                y: root.monitorY(modelData)
                width: monitorWidth
                height: monitorHeight
                opacity: modelData.enabled ? 1 : 0.45

                Behavior on x {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                Behavior on y {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                StyledRect {
                    anchors.fill: parent

                    color: monitorItem.selected ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainer
                    border.width: 2
                    border.color: monitorItem.selected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.4)
                    radius: Tokens.rounding.small

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "monitor"
                            color: monitorItem.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                            font.pointSize: Tokens.font.size.medium
                            Layout.alignment: Qt.AlignHCenter
                        }

                        StyledText {
                            text: modelData.name.length > 8 ? modelData.name.substring(0, 6) + ".." : modelData.name
                            font.pointSize: Tokens.font.size.xSmall
                            color: monitorItem.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    transform: Rotation {
                        angle: {
                            if (modelData.transform === "90")
                                return 90;
                            if (modelData.transform === "180")
                                return 180;
                            if (modelData.transform === "270")
                                return 270;
                            return 0;
                        }
                        origin.x: parent.width / 2
                        origin.y: parent.height / 2
                    }

                    MouseArea {
                        anchors.fill: parent

                        drag.target: monitorItem
                        drag.axis: Drag.XandYAxis
                        cursorShape: Qt.PointingHandCursor

                        onPressed: {
                            monitorItem.z = 10;
                            root.monitorSelected(monitorItem.index);
                        }

                        onReleased: {
                            monitorItem.z = 0;
                            const newX = Math.round((monitorItem.x - 50) * 10);
                            const newY = Math.round((monitorItem.y - 50) * 10);
                            root.monitorMoved(monitorItem.index, newX, newY);
                        }
                    }
                }

                StyledText {
                    anchors.bottom: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: Tokens.spacing.small

                    text: root.positionText(modelData)
                    font.pointSize: Tokens.font.size.xSmall
                    color: Colours.palette.m3onSurfaceVariant
                    visible: monitorItem.selected
                }
            }
        }

        StyledText {
            anchors.centerIn: parent

            text: qsTr("Drag monitors to arrange positions")
            font.pointSize: Tokens.font.size.small
            color: Colours.palette.m3onSurfaceVariant
            opacity: 0.5
            visible: root.monitors.length === 0
        }
    }
}
