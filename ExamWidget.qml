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

    // Dynamic popout height – updated by content
    property real dynamicPopoutHeight: 300   // initial minimum
    popoutHeight: dynamicPopoutHeight

    function refresh() {
        if (!pluginData.username || !pluginData.password) {
            errorMessage = "Please enter Student ID and Password in Settings.";
            return;
        }
        
        if (fetchProcess.running) {
            fetchProcess.running = false;
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
                        // Schedule popout resize after layout
                        Qt.callLater(updatePopoutSize)
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

    // Called whenever the popout content might change size
    function updatePopoutSize() {
        try {
            if (popoutColumn && popoutColumn.implicitHeight > 0) {
                dynamicPopoutHeight = popoutColumn.implicitHeight;
            }
        } catch (e) {
            // popoutColumn is not instantiated yet, ignore ReferenceError
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
    // popoutHeight is now bound to dynamicPopoutHeight

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Final Exam Schedule"
            detailsText: root.isLoading ? "Loading..." : (root.errorMessage || (root.exams.length + " upcoming exams"))
            showCloseButton: false

            Column {
                id: popoutColumn   // used to measure total content height
                width: parent.width
                spacing: Theme.spacingM

                // List of exams – no scroll, height == contentHeight
                ListView {
                    id: examList
                    width: parent.width
                    height: contentHeight   // show all items
                    model: root.exams
                    interactive: false      // no scroll needed
                    spacing: Theme.spacingS
                    visible: root.exams.length > 0

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: innerColumn.height + Theme.spacingM * 2
                        color: Theme.surfaceContainerHigh
                        radius: Theme.cornerRadius
                        border.width: 1
                        border.color: Theme.outlineLight

                        Rectangle {
                            id: indexBadge
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                            height: 24
                            radius: 12
                            color: Theme.primary

                            StyledText {
                                anchors.centerIn: parent
                                text: (index + 1).toString()
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: Theme.onPrimary
                            }
                        }

                        Column {
                            id: innerColumn
                            anchors.left: indexBadge.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingL
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80
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

                                Item {
                                    width: 110
                                    height: dateText.height
                                    StyledText {
                                        id: dateText
                                        text: "📅 " + modelData.date
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        anchors.left: parent.left
                                    }
                                }

                                Item {
                                    width: 90
                                    height: timeText.height
                                    StyledText {
                                        id: timeText
                                        text: "🕒 " + modelData.time
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        anchors.left: parent.left
                                    }
                                }

                                Item {
                                    width: parent.width - 200 - Theme.spacingM * 2
                                    height: roomText.height
                                    StyledText {
                                        id: roomText
                                        text: "📍 " + modelData.room
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        anchors.left: parent.left
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    // After items change, trigger size recalculation
                    onContentHeightChanged: root.updatePopoutSize()
                }

                // Empty state or error message
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

                // Refresh button
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