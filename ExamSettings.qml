import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dut-exams"

    StyledText {
        width: parent.width
        text: "DUT Exams Configuration"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledRect {
        width: parent.width
        height: authColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: authColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Credentials"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StringSetting {
                settingKey: "username"
                label: "Student ID"
                placeholder: "102xxxxxx"
                defaultValue: ""
            }

            StringSetting {
                settingKey: "password"
                label: "Password"
                placeholder: "••••••••"
                defaultValue: ""
            }

            StyledText {
                text: "Note: Your credentials are used only to log in to sv.dut.udn.vn and fetch your exam schedule. This information is stored locally on your machine."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.Wrap
            }
        }
    }
}
