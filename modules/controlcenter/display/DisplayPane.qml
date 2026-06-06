pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    required property Session session

    // Dummy state - sẽ thay bằng DisplayController sau
    property var monitors: [
        { name: "eDP-1", enabled: true, x: 0, y: 0, width: 1920, height: 1080, scale: 1.0, transform: "normal", vrr: false, dpms: true },
        { name: "DP-1", enabled: true, x: 1920, y: 0, width: 2560, height: 1440, scale: 1.0, transform: "normal", vrr: false, dpms: true }
    ]
    property int selectedMonitorIndex: 0
    property string activeProfile: "Default"
    property var profileNames: ["Default", "Gaming", "Work"]
    property bool isDirty: false

    function cloneMonitor(monitor) {
        const copy = {};
        for (const key in monitor)
            copy[key] = monitor[key];
        return copy;
    }

    function updateMonitor(index, updates) {
        if (index < 0 || index >= monitors.length)
            return;

        const nextMonitors = monitors.slice();
        const monitor = cloneMonitor(nextMonitors[index]);
        for (const key in updates)
            monitor[key] = updates[key];
        nextMonitors[index] = monitor;
        monitors = nextMonitors;
        isDirty = true;
    }

    function saveConfig() {
        console.log("Save config called");
        isDirty = false;
    }

    function applyProfile() {
        console.log("Apply profile called");
    }

    function switchToProfile(profileName) {
        activeProfile = profileName;
        isDirty = true;
    }

    anchors.fill: parent

    ClippingRectangle {
        id: displayPaneClip
        anchors.fill: parent
        anchors.margins: Tokens.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Tokens.padding.normal

        color: "transparent"
        radius: displayPaneBorder.innerRadius

        StyledFlickable {
            id: displayPaneFlickable

            anchors.fill: parent
            anchors.margins: Tokens.padding.large + Tokens.padding.normal
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large

            flickableDirection: Flickable.VerticalFlick
            contentHeight: displayPaneLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: displayPaneFlickable
            }

            ColumnLayout {
                id: displayPaneLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Tokens.spacing.normal

                SettingsHeader {
                    icon: "monitor"
                    title: qsTr("Display Settings")
                }

                CanvasSection {
                    id: canvasSection

                    Layout.fillWidth: true
                    Layout.preferredHeight: 220

                    monitors: root.monitors
                    selectedIndex: root.selectedMonitorIndex

                    onMonitorMoved: (index, newX, newY) => {
                        root.updateMonitor(index, {
                            "x": newX,
                            "y": newY
                        });
                    }
                    onMonitorSelected: index => {
                        root.selectedMonitorIndex = index;
                    }
                }

                ToolbarSection {
                    Layout.fillWidth: true

                    activeProfile: root.activeProfile
                    profileNames: root.profileNames
                    monitors: root.monitors
                    isDirty: root.isDirty

                    onSwitchToProfile: profile => root.switchToProfile(profile)
                    onSaveConfig: root.saveConfig()
                    onApplyProfile: root.applyProfile()
                    onAddProfile: console.log("Add profile")
                    onDeleteProfile: console.log("Delete profile")
                    onToggleMonitor: (index, enabled) => {
                        root.updateMonitor(index, {
                            "enabled": enabled
                        });
                    }
                }

                MonitorSection {
                    Layout.fillWidth: true

                    monitor: root.selectedMonitorIndex >= 0 && root.selectedMonitorIndex < root.monitors.length ? root.monitors[root.selectedMonitorIndex] : null

                    onMonitorPropertyChanged: (propertyName, value) => {
                        const updates = {};
                        updates[propertyName] = value;
                        root.updateMonitor(root.selectedMonitorIndex, updates);
                    }
                }
            }
        }
    }

    InnerBorder {
        id: displayPaneBorder
        leftThickness: 0
        rightThickness: Tokens.padding.normal
    }
}
