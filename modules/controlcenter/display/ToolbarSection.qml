import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

RowLayout {
    id: root

    required property string activeProfile
    required property var profileNames
    required property var monitors
    required property bool isDirty

    signal switchToProfile(string profileName)
    signal saveConfig()
    signal applyProfile()
    signal addProfile()
    signal deleteProfile()
    signal toggleMonitor(int index, bool enabled)

    spacing: Tokens.spacing.normal

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            text: qsTr("Active profile")
            font.pointSize: Tokens.font.size.small
            color: Colours.palette.m3onSurfaceVariant
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.profileNames

                delegate: TextButton {
                    required property string modelData

                    text: modelData
                    toggle: true
                    checked: root.activeProfile === modelData
                    type: TextButton.Tonal
                    onClicked: root.switchToProfile(modelData)
                }
            }
        }
    }

    IconButton {
        icon: "add"
        type: IconButton.Tonal
        onClicked: root.addProfile()
    }

    IconButton {
        icon: "delete"
        type: IconButton.Tonal
        disabled: root.profileNames.length <= 1
        onClicked: root.deleteProfile()
    }

    Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 40
        color: Colours.palette.m3outlineVariant
    }

    Repeater {
        model: root.monitors

        delegate: TextButton {
            required property int index
            required property var modelData

            text: modelData.name
            toggle: true
            checked: modelData.enabled
            type: TextButton.Tonal
            onClicked: root.toggleMonitor(index, internalChecked)
        }
    }

    Item {
        Layout.fillWidth: true
    }

    IconTextButton {
        icon: "save"
        text: qsTr("Save")
        opacity: root.isDirty ? 1 : 0.45
        type: IconTextButton.Filled
        onClicked: {
            if (root.isDirty)
                root.saveConfig();
        }
    }

    IconTextButton {
        icon: "play_arrow"
        text: qsTr("Apply")
        type: IconTextButton.Tonal
        onClicked: root.applyProfile()
    }
}
