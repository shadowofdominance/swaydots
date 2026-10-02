import QtQuick
import qs.config

// One list row: round icon badge, title + subtitle, and optional trailing items.
// Anything you put inside a MenuRow {...} is placed on its right side.
Rectangle {
    id: row

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool selected: false     // keyboard / hover highlight
    property bool active: false       // e.g. connected
    default property alias trailing: trailingRow.data

    signal clicked()
    signal rightClicked()
    signal hovered()

    implicitHeight: 58
    radius: Style.radiusSmall
    color: selected ? Qt.alpha(Style.accent, 0.18) : "transparent"
    border.width: selected ? 1 : 0
    border.color: Qt.alpha(Style.accent, 0.6)
    Behavior on color { ColorAnimation { duration: Style.animFast } }

    Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        radius: width / 2
        color: row.active ? Style.accent : Style.surface
        Behavior on color { ColorAnimation { duration: Style.animFast } }

        Text {
            anchors.centerIn: parent
            text: row.icon
            color: row.active ? Style.bg : Style.fg
            font.family: Style.font
            font.pixelSize: 16
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: trailingRow.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: row.title
            elide: Text.ElideRight
            color: Style.fg
            font.family: Style.font
            font.pixelSize: Style.fontNormal
            font.bold: row.active
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: row.subtitle
            elide: Text.ElideRight
            color: row.active ? Style.accent : Style.muted
            font.family: Style.font
            font.pixelSize: Style.fontSmall
        }
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: row.hovered()
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) row.rightClicked()
            else row.clicked()
        }
    }
}
