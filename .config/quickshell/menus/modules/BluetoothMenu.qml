import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Bluetooth popup (top-right, under Waybar). Talks to BlueZ through bluetoothctl.
//   Enter / click : connect (pairs first if the device is new) / disconnect
//   P             : Bluetooth on/off      S : scan for devices
//   right-click / F : remove a paired device
MenuWindow {
    id: root
    scrimColor: "transparent"

    property int topOffset: 62
    property int rightOffset: 14

    property var devices: []
    property string listKey: ""
    property bool btOn: true
    property bool available: true
    property int selected: 0
    property string status: ""
    property bool busy: false
    readonly property bool scanning: scanProc.running

    // ---------- helpers ----------
    function firstLine(s) { return ((s || "").split("\n").filter(l => l.trim() !== "").pop() || "").trim() }
    function say(msg, isBusy) { status = msg; busy = !!isBusy }

    function iconFor(t) {
        if (t.indexOf("headphone") >= 0 || t.indexOf("headset") >= 0) return "\uf025"
        if (t.indexOf("speaker") >= 0 || t.indexOf("audio") >= 0) return "\uf028"
        if (t.indexOf("mouse") >= 0) return "\uf245"
        if (t.indexOf("keyboard") >= 0) return "\uf11c"
        if (t.indexOf("gaming") >= 0) return "\uf11b"
        if (t.indexOf("phone") >= 0) return "\uf10b"
        if (t.indexOf("computer") >= 0) return "\uf109"
        return "\uf293"
    }

    function refresh() {
        powerRun.run(["bluetoothctl", "show"], (code, out) => {
            if (code !== 0 || out.indexOf("Powered:") < 0) {
                available = false; btOn = false; devices = []; listKey = ""
                return
            }
            available = true
            btOn = /Powered:\s*yes/.test(out)
            fetchDevices()
        })
    }

    function fetchDevices() {
        const script = 'for m in $(bluetoothctl devices | awk \'{print $2}\'); do echo "@@$m"; bluetoothctl info "$m"; done'
        listRun.run(["sh", "-c", script], (code, out) => {
            const list = []
            const macLike = /^([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}$/
            for (const block of out.split("@@").slice(1)) {
                const lines = block.split("\n")
                const d = { mac: lines[0].trim(), name: "", type: "", paired: false, connected: false, battery: -1 }
                for (const raw of lines.slice(1)) {
                    const t = raw.trim()
                    if (t.startsWith("Alias:")) d.name = t.slice(6).trim()
                    else if (t.startsWith("Name:") && d.name === "") d.name = t.slice(5).trim()
                    else if (t.startsWith("Icon:")) d.type = t.slice(5).trim()
                    else if (t.startsWith("Paired:")) d.paired = t.endsWith("yes")
                    else if (t.startsWith("Connected:")) d.connected = t.endsWith("yes")
                    else if (t.startsWith("Battery Percentage:")) {
                        const m = t.match(/\((\d+)\)/)
                        if (m) d.battery = parseInt(m[1])
                    }
                }
                if (d.name === "") d.name = d.mac
                // hide anonymous devices (only a MAC address) unless they are paired
                if (macLike.test(d.name) && !d.paired) continue
                list.push(d)
            }
            list.sort((a, b) => ((b.connected ? 1 : 0) - (a.connected ? 1 : 0))
                             || ((b.paired ? 1 : 0) - (a.paired ? 1 : 0))
                             || a.name.localeCompare(b.name))
            const key = list.map(d => d.mac + "|" + (d.connected ? 1 : 0) + (d.paired ? 1 : 0) + d.battery + d.name).join(",")
            if (key === listKey) return
            listKey = key
            const y = list_.contentY
            devices = list
            selected = Math.min(selected, Math.max(0, list.length - 1))
            Qt.callLater(() => { list_.contentY = y })
        })
    }

    function move(n) {
        if (devices.length === 0) return
        selected = Math.max(0, Math.min(devices.length - 1, selected + n))
    }

    function reportResult(okMsg, code, out) {
        const line = firstLine(out)
        const failed = code !== 0 || /fail|error|not available|timeout/i.test(line)
        say(failed ? (line || "Failed") : okMsg, false)
        refresh()
    }

    function activate(i) {
        const d = devices[i]
        if (!d || busy || !btOn) return
        if (d.connected) {
            say("Disconnecting " + d.name + "…", true)
            actionRun.run(["bluetoothctl", "disconnect", d.mac], (c, o) => reportResult("Disconnected", c, o))
        } else if (d.paired) {
            say("Connecting to " + d.name + "…", true)
            actionRun.run(["sh", "-c", 'timeout 25 bluetoothctl connect "$1"', "sh", d.mac],
                          (c, o) => reportResult("Connected to " + d.name, c, o))
        } else {
            say("Pairing with " + d.name + "…", true)
            const script = 'timeout 40 bluetoothctl pair "$1" && bluetoothctl trust "$1" && timeout 25 bluetoothctl connect "$1"'
            actionRun.run(["sh", "-c", script, "sh", d.mac],
                          (c, o) => reportResult("Paired and connected to " + d.name, c, o))
        }
    }

    function forget(i) {
        const d = devices[i]
        if (!d || !d.paired || busy) return
        say("Removing " + d.name + "…", true)
        actionRun.run(["bluetoothctl", "remove", d.mac], (c, o) => reportResult("Removed " + d.name, c, o))
    }

    function togglePower() {
        if (!available) return
        const target = btOn ? "off" : "on"
        btOn = !btOn
        if (!btOn) scanProc.running = false
        actionRun.run(["sh", "-c", 'rfkill unblock bluetooth 2>/dev/null; bluetoothctl power "$1"', "sh", target],
                      (c, o) => {
            if (c !== 0) say(firstLine(o), false)
            refresh()
        })
    }

    function toggleScan() {
        if (!btOn) return
        scanProc.running = !scanProc.running
    }

    onSelectedChanged: list_.positionViewAtIndex(selected, ListView.Contain)

    onOpenChanged: {
        if (open) {
            status = ""
            busy = false
            selected = 0
            refresh()
        } else {
            scanProc.running = false
        }
    }

    onKeyPressed: event => {
        switch (event.key) {
        case Qt.Key_Down:
        case Qt.Key_J:      move(1); break
        case Qt.Key_Up:
        case Qt.Key_K:      move(-1); break
        case Qt.Key_Return:
        case Qt.Key_Enter:  activate(selected); break
        case Qt.Key_P:      togglePower(); break
        case Qt.Key_S:      toggleScan(); break
        case Qt.Key_F:
        case Qt.Key_Delete: forget(selected); break
        }
        event.accepted = true
    }

    // ---------- processes & timers ----------
    Runner { id: powerRun }
    Runner { id: listRun }
    Runner { id: actionRun }

    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "12", "scan", "on"]
    }

    Timer {
        interval: root.scanning ? 2000 : 4000
        repeat: true
        running: root.open
        onTriggered: root.refresh()
    }

    // ---------- UI ----------
    Surface {
        id: panel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.topOffset - (1 - root.progress) * 10
        anchors.rightMargin: root.rightOffset
        width: 400
        height: col.implicitHeight + 28
        radius: Style.radius
        opacity: root.progress

        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            Item {
                width: parent.width
                height: 40

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf293   Bluetooth"
                    color: Style.fg
                    font.family: Style.font
                    font.pixelSize: Style.fontLarge
                    font.bold: true
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.btOn
                        color: root.scanning ? Style.accent : Style.surface
                        Behavior on color { ColorAnimation { duration: Style.animFast } }

                        Text {
                            id: scanIcon
                            anchors.centerIn: parent
                            text: "\uf021"
                            color: root.scanning ? Style.bg : Style.fg
                            font.family: Style.font
                            font.pixelSize: 14
                            RotationAnimator on rotation {
                                running: root.scanning
                                from: 0; to: 360; duration: 1200; loops: Animation.Infinite
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleScan()
                        }
                    }

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.btOn
                        onToggled: root.togglePower()
                    }
                }
            }

            ListView {
                id: list_
                width: parent.width
                height: Math.min(contentHeight, 340)
                visible: root.available && root.btOn && root.devices.length > 0
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: root.devices

                delegate: MenuRow {
                    id: item
                    required property int index
                    required property var modelData

                    width: ListView.view.width
                    icon: root.iconFor(modelData.type)
                    title: modelData.name
                    subtitle: modelData.connected ? "Connected"
                            : modelData.paired ? "Paired" : "Available"
                    active: modelData.connected
                    selected: root.selected === index

                    onHovered: root.selected = index
                    onClicked: { root.selected = index; root.activate(index) }
                    onRightClicked: root.forget(index)

                    Text {
                        visible: item.modelData.battery >= 0
                        text: "\uf240  " + item.modelData.battery + "%"
                        color: item.modelData.battery > 40 ? Style.green
                             : item.modelData.battery > 15 ? Style.yellow : Style.red
                        font.family: Style.font
                        font.pixelSize: Style.fontSmall
                    }
                }
            }

            Text {
                visible: !list_.visible
                width: parent.width
                height: 60
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: !root.available ? "No Bluetooth adapter found"
                    : !root.btOn ? "Bluetooth is turned off"
                    : root.scanning ? "Searching for devices…" : "No devices — press S to scan"
                color: Style.muted
                font.family: Style.font
                font.pixelSize: Style.fontNormal
            }

            Text {
                visible: root.status !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                text: root.status
                color: root.busy ? Style.cyan : Style.fg
                font.family: Style.font
                font.pixelSize: Style.fontSmall
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Enter connect · S scan · P on/off · right-click remove"
                color: Style.muted
                font.family: Style.font
                font.pixelSize: Style.fontSmall
            }
        }
    }
}
