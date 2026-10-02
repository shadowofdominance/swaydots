import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.components

// Carousel wallpaper picker: the selected card is wide, the rest are slim
// portrait strips that fade out towards the screen edges.
MenuWindow {
    id: root

    // ---- settings ----
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallhaven/Future"

    // ---- geometry (scales with screen height) ----
    readonly property real cardH:      Math.min(height * 0.5, 520)
    readonly property real cardWide:   cardH * 1.65
    readonly property real cardNarrow: cardH * 0.35
    readonly property real cardGap:    Style.spacing

    // ---- state ----
    readonly property int count: files.count
    property int current: 0      // selected index
    property real pos: 0         // animated "fractional" index that drives the layout
    property bool snap: false    // true = jump without animating

    onCurrentChanged: pos = current
    Behavior on pos {
        enabled: !root.snap
        NumberAnimation { duration: Style.animSlow; easing.type: Easing.OutCubic }
    }

    function step(n) {
        if (count > 0)
            current = Math.max(0, Math.min(count - 1, current + n))
    }

    function apply() {
        if (count === 0) return
        applyProc.command = ["sh", Quickshell.shellPath("scripts/set-wallpaper.sh"),
                             files.get(current, "filePath")]
        applyProc.running = true
        close()
    }

    // Start on the wallpaper that is currently set
    function syncToSaved() {
        saved.reload()
        const target = (saved.text() || "").trim()
        if (!target) return
        for (let i = 0; i < files.count; i++) {
            if (files.get(i, "filePath") === target) {
                snap = true
                current = i
                pos = i
                snap = false
                return
            }
        }
    }

    onOpenChanged: if (open) syncToSaved()

    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_H:      step(-1); break
        case Qt.Key_Right:
        case Qt.Key_L:      step(1); break
        case Qt.Key_Home:   current = 0; break
        case Qt.Key_End:    current = Math.max(0, count - 1); break
        case Qt.Key_Return:
        case Qt.Key_Enter:  apply(); break
        }
        event.accepted = true
    }

    // ---- data ----
    FolderListModel {
        id: files
        folder: "file://" + root.wallpaperDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp",
                      "*.JPG", "*.JPEG", "*.PNG", "*.WEBP"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    FileView {
        id: saved
        path: Quickshell.env("HOME") + "/.cache/quickshell-menus/wallpaper"
        blockLoading: true
        printErrors: false
    }

    Process { id: applyProc }

    // ---- UI ----
    WheelHandler {
        onWheel: event => root.step(event.angleDelta.y < 0 ? 1 : -1)
    }

    Item {
        id: carousel
        width: root.width
        height: root.cardH
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (1 - root.progress) * 40
        opacity: root.progress

        readonly property real cx: width / 2

        Repeater {
            model: files

            delegate: ClippingRectangle {
                id: card

                required property int index
                required property string fileName
                required property string filePath
                required property url fileUrl

                // hat = 1 for the selected card, 0 when a full slot away
                readonly property real hat: Math.max(0, 1 - Math.abs(index - root.pos))
                // extra "width debt" of all cards left of this one (closed form, O(1))
                readonly property real lo: Math.floor(root.pos)
                readonly property real fr: root.pos - lo
                readonly property real widen: (lo < index ? 1 - fr : 0)
                                            + (lo + 1 < index ? fr : 0)
                readonly property real slot: root.cardNarrow + root.cardGap
                readonly property real mid: x + width / 2
                readonly property real edgeDist: Math.min(mid, root.width - mid)

                width: root.cardNarrow + (root.cardWide - root.cardNarrow) * hat
                height: root.cardH
                x: carousel.cx - root.cardWide / 2
                   + (index - root.pos) * slot
                   + (root.cardWide - root.cardNarrow) * widen

                visible: x + width > -40 && x < root.width + 40
                radius: Style.radius
                color: Style.surface
                border.width: Style.borderWidth * hat
                border.color: Style.accent
                // dim unselected cards a little, and fade everything near the screen edges
                opacity: Math.max(0, Math.min(1, edgeDist / (root.width * 0.16)))
                         * (0.7 + 0.3 * hat)

                Image {
                    anchors.fill: parent
                    source: card.visible ? card.fileUrl : ""
                    sourceSize: Qt.size(1200, 800)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Style.animMed } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.index === root.current) root.apply()
                        else root.current = card.index
                    }
                }
            }
        }
    }

    // file name pill + key hints under the carousel
    Surface {
        id: nameTag
        visible: root.count > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: carousel.bottom
        anchors.topMargin: 26
        width: nameText.implicitWidth + 36
        height: 40
        opacity: root.progress

        Text {
            id: nameText
            anchors.centerIn: parent
            text: (root.current + 1) + " / " + root.count + "   "
                  + (root.count > 0 ? files.get(root.current, "fileName") : "")
            color: Style.fg
            font.family: Style.font
            font.pixelSize: Style.fontNormal
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: nameTag.bottom
        anchors.topMargin: 12
        opacity: root.progress * 0.8
        text: "← →  browse     Enter  apply     Esc  close"
        color: Style.muted
        font.family: Style.font
        font.pixelSize: Style.fontSmall
    }

    Text {
        visible: root.count === 0
        anchors.centerIn: parent
        text: "No wallpapers found in\n" + root.wallpaperDir
        horizontalAlignment: Text.AlignHCenter
        color: Style.fg
        font.family: Style.font
        font.pixelSize: Style.fontLarge
        opacity: root.progress
    }
}
