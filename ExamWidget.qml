import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var exams: []
    property string errorMessage: ""
    property bool isLoading: false
    readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")

    function refresh() {
        if (!pluginData.username || !pluginData.password) {
            errorMessage = "Please enter Student ID and Password in Settings.";
            return;
        }
        
        if (fetchProcess.running) {
            fetchProcess.terminate();
        }
        
        isLoading = true;
        errorMessage = "";
        fetchProcess.running = true;
    }

    // Auto refresh when credentials change in settings
    property string _user: pluginData.username || ""
    property string _pass: pluginData.password || ""
    on_UserChanged: refresh()
    on_PassChanged: refresh()

    Component.onCompleted: {
        // Use a small delay to ensure PluginService and pluginData are fully synced
        Qt.callLater(() => {
            refresh();
        });
    }

    Timer {
        interval: 1000 * 60 * 60 // 1 hour
        running: true
        repeat: true
        onTriggered: refresh()
    }

    Process {
        id: fetchProcess
        command: ["python3", root.pluginDir + "/fetch_exams.py", pluginData.username || "", pluginData.password || ""]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    var result = JSON.parse(data);
                    if (result.error) {
                        root.errorMessage = result.error;
                    } else if (Array.isArray(result)) {
                        root.exams = result;
                        root.errorMessage = "";
                    }
                } catch (e) {
                    root.errorMessage = "Failed to process data from server.";
                    console.error("Failed to parse JSON:", e, "Data:", data);
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isLoading = false;
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "event"
                size: Theme.iconSizeSmall
                color: root.exams.length > 0 ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.exams.length + " Exams"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                anchors.verticalCenter: parent.verticalCenter
                visible: root.exams.length > 0
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingS
            DankIcon {
                name: "event"
                size: Theme.iconSizeSmall
                color: root.exams.length > 0 ? Theme.primary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.exams.length.toString()
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
                rotation: 90
                visible: root.exams.length > 0
            }
        }
    }

    popoutWidth: 400
    popoutHeight: 450

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Final Exam Schedule"
            detailsText: root.isLoading ? "Loading..." : (root.errorMessage || (root.exams.length + " upcoming exams"))
            showCloseButton: false
            
            Column {
                width: parent.width
                spacing: Theme.spacingM

                ListView {
                    width: parent.width
                    height: Math.min(320, contentHeight)
                    model: root.exams
                    clip: true
                    spacing: Theme.spacingS
                    visible: root.exams.length > 0
                    
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: innerColumn.height + Theme.spacingM * 2
                        color: Theme.surfaceContainer
                        radius: Theme.radiusM

                        Column {
                            id: innerColumn
                            anchors.centerIn: parent
                            width: parent.width - Theme.spacingL * 2
                            spacing: 4

                            StyledText {
                                text: modelData.course
                                width: parent.width
                                wrapMode: Text.Wrap
                                font.weight: Font.Bold
                                color: Theme.primary
                                font.pixelSize: Theme.fontSizeMedium
                            }

                            Row {
                                spacing: Theme.spacingM
                                width: parent.width
                                
                                StyledText {
                                    text: "📅 " + modelData.date
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }
                                StyledText {
                                    text: "🕒 " + modelData.time
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }
                                StyledText {
                                    text: "📍 " + modelData.room
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: (root.exams.length === 0 || root.errorMessage) && !root.isLoading
                    
                    DankIcon {
                        name: root.errorMessage ? "error_outline" : "event_available"
                        size: 48
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    StyledText {
                        text: root.errorMessage || "No exam schedule found."
                        width: parent.width - Theme.spacingL * 2
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.surfaceVariantText
                        wrapMode: Text.Wrap
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                DankButton {
                    text: "Refresh"
                    iconName: "refresh"
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: root.refresh()
                    enabled: !root.isLoading
                    backgroundColor: Theme.surfaceContainerHigh
                    textColor: Theme.surfaceText
                }
            }
        }
    }
}
