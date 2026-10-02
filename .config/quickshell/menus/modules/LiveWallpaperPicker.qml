import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.components

// Same carousel as the static picker, but for video wallpapers (played with mpvpaper).
// Previews are generated once with ffmpeg and cached in ~/.cache/quickshell-menus/thumbs.
//   Enter / click : play      S : stop live wallpaper      Esc : close
MenuWindow {
    id: root

    // ---- settings ----
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallhaven/Live/"
    property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell-menus/thumbs"

    // ---- geometry ----
    readonly property real cardH:      Math.min(height * 0.5, 520)
    readonly property real cardWide:   cardH * 1.65
    readonly property real cardNarrow: cardH * 0.35
    readonly property real cardGap:    Style.spacing

    // ---- state ----
    readonly property int count: files.count
    property int current: 0
    property real pos: 0
    property bool snap: false
    property int thumbGen: 0          // bumped when preview generation finishes

    onCurrentChanged: pos = current
    Behavior on pos {
        enabled: !root.snap
        NumberAnimation { duration: Style.animSlow; easing.type: Easing.OutCubic }
    }

    function step(n) {
        if (count > 0)
            current = Math.max(0, Math.min(count - 1, current + n))
    }

    function scriptRun(args) {
        applyProc.command = ["sh", Quickshell.shellPath("scripts/set-live-wallpaper.sh")].concat(args)
        applyProc.running = true
    }

    function apply() {
        if (count === 0) return
        scriptRun([files.get(current, "filePath")])
        close()
    }

    function stopLive() {
        scriptRun(["--stop"])
        close()
    }

    // preview file name: safe characters + a small hash so different names never collide
    function thumbPath(fileName) {
        let h = 5381
        for (let i = 0; i < fileName.length; i++)
            h = ((h * 33) ^ fileName.charCodeAt(i)) >>> 0
        return thumbDir + "/" + fileName.replace(/[^A-Za-z0-9._-]/g, "_") + "_" + h.toString(16) + ".jpg"
    }

    function makeThumbs() {
        if (files.count === 0) return
        const args = [Quickshell.shellPath("scripts/make-thumbs.sh")]
        for (let i = 0; i < files.count; i++) {
            args.push(files.get(i, "filePath"))
            args.push(thumbPath(files.get(i, "fileName")))
        }
        thumbRun.run(["sh"].concat(args), () => { root.thumbGen++ })
    }

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

    onOpenChanged: if (open) { syncToSaved(); makeThumbs() }
    onCountChanged: if (open) makeThumbs()

    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_H:      step(-1); break
        case Qt.Key_Right:
        case Qt.Key_L:      step(1); break
        case Qt.Key_Home:   current = 0; break
        case Qt.Key_End:    current = Math.max(0, count - 1); break
        case Qt.Key_S:      stopLive(); break
        case Qt.Key_Return:
        case Qt.Key_Enter:  apply(); break
        }
        event.accepted = true
    }

    // ---- data ----
    FolderListModel {
        id: files
        folder: "file://" + root.wallpaperDir
        nameFilters: ["*.mp4", "*.mkv", "*.webm", "*.mov", "*.avi", "*.gif",
                      "*.MP4", "*.MKV", "*.WEBM", "*.MOV", "*.AVI", "*.GIF"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    FileView {
        id: saved
        path: Quickshell.env("HOME") + "/.cache/quickshell-menus/live-wallpaper"
        blockLoading: true
        printErrors: false
    }

    Process { id: applyProc }
    Runner { id: thumbRun }

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

                readonly property real hat: Math.max(0, 1 - Math.abs(index - root.pos))
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
                opacity: Math.max(0, Math.min(1, edgeDist / (root.width * 0.16)))
                         * (0.7 + 0.3 * hat)

                // placeholder while the preview doesn't exist yet
                Text {
                    anchors.centerIn: parent
                    visible: thumb.status !== Image.Ready
                    text: "\uf008"
                    color: Style.muted
                    font.family: Style.font
                    font.pixelSize: 40
                }

                Image {
                    id: thumb
                    anchors.fill: parent
                    source: (card.visible && root.thumbGen > 0)
                            ? "file://" + root.thumbPath(card.fileName) : ""
                    sourceSize: Qt.size(1200, 800)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Style.animMed } }
                }

                // LIVE badge on the selected card
                Surface {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 14
                    width: liveText.implicitWidth + 24
                    height: 28
                    opacity: card.hat
                    Text {
                        id: liveText
                        anchors.centerIn: parent
                        text: "\uf04b  LIVE"
                        color: Style.pink
                        font.family: Style.font
                        font.pixelSize: Style.fontSmall
                        font.bold: true
                    }
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
        text: thumbRun.running ? "Generating previews…"
                               : "← →  browse     Enter  play     S  stop live wallpaper     Esc  close"
        color: Style.muted
        font.family: Style.font
        font.pixelSize: Style.fontSmall
    }

    Text {
        visible: root.count === 0
        anchors.centerIn: parent
        text: "No videos found in\n" + root.wallpaperDir
        horizontalAlignment: Text.AlignHCenter
        color: Style.fg
        font.family: Style.font
        font.pixelSize: Style.fontLarge
        opacity: root.progress
    }
}
