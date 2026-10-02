import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Base for every full-screen pop-up menu.
// Gives you: dim scrim, fade in/out (`progress` 0..1), exclusive keyboard focus,
// Esc / click-outside to close, and a `keyPressed` signal for your own keys.
//
// Children you put inside a MenuWindow are drawn above the scrim.
PanelWindow {
    id: win

    property bool open: false
    property real progress: open ? 1 : 0
    signal keyPressed(var event)

    function show()   { open = true }
    function close()  { open = false }
    function toggle() { open = !open }

    Behavior on progress {
        NumberAnimation { duration: Style.animMed; easing.type: Easing.OutCubic }
    }

    visible: open || progress > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "qs-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) keys.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        color: Style.scrim
        opacity: win.progress
        MouseArea {
            anchors.fill: parent
            onClicked: win.close()
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                win.close()
                event.accepted = true
            } else {
                win.keyPressed(event)
            }
        }
    }
}
