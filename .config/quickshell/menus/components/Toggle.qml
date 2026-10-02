import QtQuick
import qs.config

// On/off switch. Set `checked` from your own state and react to `toggled()`.
Rectangle {
    id: sw

    property bool checked: false
    signal toggled()

    implicitWidth: 46
    implicitHeight: 26
    radius: height / 2
    color: checked ? Style.accent : Style.surface
    Behavior on color { ColorAnimation { duration: Style.animFast } }

    Rectangle {
        width: 20
        height: 20
        radius: 10
        y: 3
        x: sw.checked ? sw.width - width - 3 : 3
        color: sw.checked ? Style.bg : Style.fg
        Behavior on x { NumberAnimation { duration: Style.animFast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Style.animFast } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
