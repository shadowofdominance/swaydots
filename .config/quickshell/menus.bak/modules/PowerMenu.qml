import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Simple power menu: a row of rounded icon buttons, the selected one lit in the accent colour.
// Icons are Nerd Font glyphs, so Style.font must be a Nerd Font.
MenuWindow {
    id: root

    // ---- edit commands here ----
    property var actions: [
        { icon: "\uf023", label: "Lock",      cmd: ["swaylock", "-f"] },
        { icon: "\uf186", label: "Sleep",     cmd: ["systemctl", "suspend"] },
        { icon: "\uf08b", label: "Log out",   cmd: ["swaymsg", "exit"] },
        { icon: "\uf021", label: "Reboot",    cmd: ["systemctl", "reboot"] },
        { icon: "\uf011", label: "Shut down", cmd: ["systemctl", "poweroff"] }
    ]

    property int selected: 0
    readonly property int btnSize: 128
    readonly property int btnRadius: 30

    onOpenChanged: if (open) selected = 0

    function move(n) {
        selected = Math.max(0, Math.min(actions.length - 1, selected + n))
    }

    function run(i) {
        proc.command = actions[i].cmd
        proc.running = true
        close()
    }

    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_H:      move(-1); break
        case Qt.Key_Right:
        case Qt.Key_L:      move(1); break
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:  run(selected); break
        case Qt.Key_1: selected = 0; break
        case Qt.Key_2: selected = 1; break
        case Qt.Key_3: selected = 2; break
        case Qt.Key_4: selected = 3; break
        case Qt.Key_5: selected = 4; break
        }
        event.accepted = true
    }

    Process { id: proc }

    // ---- buttons ----
    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (1 - root.progress) * 30
        spacing: 22
        opacity: root.progress

        Repeater {
            model: root.actions

            delegate: Rectangle {
                id: btn

                required property int index
                required property var modelData
                readonly property bool active: root.selected === index

                width: root.btnSize
                height: root.btnSize
                radius: root.btnRadius
                color: active ? Style.accent : Style.bg
                border.width: 1
                border.color: active ? "transparent" : Style.outline
                scale: active ? 1.06 : 1.0

                Behavior on color { ColorAnimation { duration: Style.animFast } }
                Behavior on scale { NumberAnimation { duration: Style.animFast; easing.type: Easing.OutCubic } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.45
                    shadowBlur: 0.9
                    shadowVerticalOffset: 10
                }

                Text {
                    anchors.centerIn: parent
                    text: btn.modelData.icon
                    color: btn.active ? Style.bg : Style.fg
                    font.family: Style.font
                    font.pixelSize: 46
                    Behavior on color { ColorAnimation { duration: Style.animFast } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selected = btn.index
                    onClicked: root.run(btn.index)
                }
            }
        }
    }

    // label of the selected action
    Surface {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: row.bottom
        anchors.topMargin: 34
        width: labelText.implicitWidth + 36
        height: 40
        opacity: root.progress

        Text {
            id: labelText
            anchors.centerIn: parent
            text: root.actions[root.selected].label
            color: Style.fg
            font.family: Style.font
            font.pixelSize: Style.fontNormal
        }
    }

    // ---- close button (top right) ----
    Rectangle {
        id: closeBtn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 28
        width: 52
        height: 52
        radius: width / 2
        color: closeArea.containsMouse ? Style.accent : Style.surface
        opacity: root.progress
        Behavior on color { ColorAnimation { duration: Style.animFast } }

        Text {
            anchors.centerIn: parent
            text: "\uf00d"
            color: closeArea.containsMouse ? Style.bg : Style.fg
            font.family: Style.font
            font.pixelSize: 20
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.close()
        }
    }
}
