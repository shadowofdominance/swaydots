import QtQuick
import Quickshell
import qs.config
import qs.components

// Wi-Fi popup (top-right, under Waybar). Talks to NetworkManager through nmcli.
//   Enter / click : connect (or disconnect if already connected)
//   W             : Wi-Fi on/off        R : rescan
//   right-click / F : forget a saved network
MenuWindow {
    id: root
    scrimColor: "transparent"

    // where the popup sits (match your Waybar margins)
    property int topOffset: 62
    property int rightOffset: 14

    property var networks: []
    property string listKey: ""
    property bool wifiOn: true
    property int selected: 0
    property string promptSsid: ""
    property string status: ""
    property bool busy: false

    // ---------- helpers ----------
    function splitTerse(line) {           // split nmcli -t output on unescaped ':'
        const parts = []
        let cur = ""
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (ch === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++ }
            else if (ch === ":") { parts.push(cur); cur = "" }
            else cur += ch
        }
        parts.push(cur)
        return parts
    }

    function firstLine(s) { return ((s || "").split("\n")[0] || "").trim() }
    function say(msg, isBusy) { status = msg; busy = !!isBusy }

    function refresh() {
        radioRun.run(["nmcli", "radio", "wifi"], (code, out) => {
            wifiOn = out.trim() === "enabled"
            if (wifiOn) fetchNetworks()
            else { networks = []; listKey = "" }
        })
    }

    function fetchNetworks() {
        knownRun.run(["nmcli", "-t", "-e", "yes", "-f", "NAME,TYPE", "connection", "show"], (c1, o1) => {
            const known = {}
            for (const line of o1.split("\n")) {
                const p = splitTerse(line)
                if (p.length >= 2 && p[1] === "802-11-wireless") known[p[0]] = true
            }
            listRun.run(["nmcli", "-t", "-e", "yes", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
                         "dev", "wifi", "list", "--rescan", "no"], (c2, o2) => {
                const map = {}
                for (const line of o2.split("\n")) {
                    const p = splitTerse(line)
                    if (p.length < 4 || p[1] === "") continue
                    const ssid = p[1]
                    const sig = parseInt(p[2]) || 0
                    const sec = p[3] !== "" && p[3] !== "--"
                    const act = p[0] === "*"
                    const cur = map[ssid]
                    if (!cur) map[ssid] = { ssid: ssid, signal: sig, secured: sec, active: act, known: !!known[ssid] }
                    else { cur.signal = Math.max(cur.signal, sig); cur.active = cur.active || act }
                }
                const arr = Object.values(map)
                arr.sort((a, b) => ((b.active ? 1 : 0) - (a.active ? 1 : 0)) || (b.signal - a.signal))
                const key = arr.map(n => n.ssid + "|" + (n.active ? 1 : 0) + (n.known ? 1 : 0)
                                         + (n.secured ? 1 : 0) + Math.round(n.signal / 10)).join(",")
                if (key === listKey) return
                listKey = key
                const y = list.contentY
                networks = arr
                selected = Math.min(selected, Math.max(0, arr.length - 1))
                Qt.callLater(() => { list.contentY = y })
            })
        })
    }

    function rescan() { rescanRun.run(["nmcli", "dev", "wifi", "rescan"]) }

    function move(n) {
        if (networks.length === 0) return
        selected = Math.max(0, Math.min(networks.length - 1, selected + n))
    }

    function activate(i) {
        const n = networks[i]
        if (!n || busy) return
        if (n.active) {
            say("Disconnecting…", true)
            actionRun.run(["nmcli", "connection", "down", "id", n.ssid], (code, out) => {
                say(code === 0 ? "Disconnected" : firstLine(out), false)
                refresh()
            })
        } else if (!n.known && n.secured) {
            promptSsid = n.ssid
            pwField.text = ""
            pwField.forceActiveFocus()
        } else {
            connectTo(n, "")
        }
    }

    function connectTo(n, password) {
        say("Connecting to " + n.ssid + "…", true)
        let cmd
        if (password !== "") cmd = ["nmcli", "dev", "wifi", "connect", n.ssid, "password", password]
        else if (n.known) cmd = ["nmcli", "connection", "up", "id", n.ssid]
        else cmd = ["nmcli", "dev", "wifi", "connect", n.ssid]

        actionRun.run(cmd, (code, out) => {
            if (code !== 0 && n.known && password === "") {
                // saved profile has a different name: fall back to a normal connect
                actionRun.run(["nmcli", "dev", "wifi", "connect", n.ssid], (c2, o2) => afterConnect(n, password, c2, o2))
                return
            }
            afterConnect(n, password, code, out)
        })
    }

    function afterConnect(n, password, code, out) {
        if (code === 0) {
            say("Connected to " + n.ssid, false)
            promptSsid = ""
            refocus()
        } else {
            say(firstLine(out) || "Could not connect", false)
            if (password !== "") cleanupRun.run(["nmcli", "connection", "delete", "id", n.ssid])
        }
        refresh()
    }

    function submitPassword() {
        if (pwField.text === "" || busy) return
        for (const n of networks) {
            if (n.ssid === promptSsid) { connectTo(n, pwField.text); return }
        }
    }

    function cancelPrompt() {
        promptSsid = ""
        pwField.text = ""
        refocus()
    }

    function forget(i) {
        const n = networks[i]
        if (!n || !n.known || busy) return
        say("Forgetting " + n.ssid + "…", true)
        actionRun.run(["nmcli", "connection", "delete", "id", n.ssid], (code, out) => {
            say(code === 0 ? "Forgot " + n.ssid : firstLine(out), false)
            refresh()
        })
    }

    function toggleRadio() {
        const target = wifiOn ? "off" : "on"
        wifiOn = !wifiOn
        if (!wifiOn) { networks = []; listKey = "" }
        actionRun.run(["nmcli", "radio", "wifi", target], () => {
            rescan()
            settle.restart()
        })
    }

    onSelectedChanged: list.positionViewAtIndex(selected, ListView.Contain)

    onOpenChanged: {
        if (open) {
            promptSsid = ""
            status = ""
            busy = false
            selected = 0
            refresh()
            rescan()
            settle.restart()
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
        case Qt.Key_W:      toggleRadio(); break
        case Qt.Key_R:      rescan(); settle.restart(); break
        case Qt.Key_F:
        case Qt.Key_Delete: forget(selected); break
        }
        event.accepted = true
    }

    // ---------- processes & timers ----------
    Runner { id: radioRun }
    Runner { id: knownRun }
    Runner { id: listRun }
    Runner { id: actionRun }
    Runner { id: rescanRun }
    Runner { id: cleanupRun }

    Timer { id: settle; interval: 3000; onTriggered: root.refresh() }
    Timer {
        interval: 6000; repeat: true; running: root.open
        onTriggered: if (!root.busy && root.promptSsid === "") root.refresh()
    }
    Timer { interval: 20000; repeat: true; running: root.open; onTriggered: root.rescan() }

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

        MouseArea { anchors.fill: parent }   // don't let clicks on the panel reach the scrim

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            Item {
                width: parent.width
                height: 40

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf1eb   Wi-Fi"
                    color: Style.fg
                    font.family: Style.font
                    font.pixelSize: Style.fontLarge
                    font.bold: true
                }
                Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.wifiOn
                    onToggled: root.toggleRadio()
                }
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(contentHeight, 340)
                visible: root.wifiOn && root.networks.length > 0
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: root.networks

                delegate: MenuRow {
                    id: item
                    required property int index
                    required property var modelData

                    width: ListView.view.width
                    icon: "\uf1eb"
                    title: modelData.ssid
                    subtitle: modelData.active ? "Connected"
                            : modelData.known ? "Saved"
                            : modelData.secured ? "Secured" : "Open"
                    active: modelData.active
                    selected: root.selected === index

                    onHovered: root.selected = index
                    onClicked: { root.selected = index; root.activate(index) }
                    onRightClicked: root.forget(index)

                    Text {
                        visible: item.modelData.secured
                        text: "\uf023"
                        color: Style.muted
                        font.family: Style.font
                        font.pixelSize: 13
                    }
                    Text {
                        text: item.modelData.signal + "%"
                        color: item.modelData.signal > 60 ? Style.green
                             : item.modelData.signal > 30 ? Style.yellow : Style.orange
                        font.family: Style.font
                        font.pixelSize: Style.fontSmall
                    }
                }
            }

            Text {
                visible: !list.visible
                width: parent.width
                height: 60
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.wifiOn ? "No networks found" : "Wi-Fi is turned off"
                color: Style.muted
                font.family: Style.font
                font.pixelSize: Style.fontNormal
            }

            Surface {
                visible: root.promptSsid !== ""
                width: parent.width
                height: 48
                color: Style.surface

                TextInput {
                    id: pwField
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: goBtn.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    clip: true
                    selectByMouse: true
                    color: Style.fg
                    font.family: Style.font
                    font.pixelSize: Style.fontNormal
                    Keys.onReturnPressed: root.submitPassword()
                    Keys.onEnterPressed: root.submitPassword()
                    Keys.onEscapePressed: root.cancelPrompt()

                    Text {
                        visible: pwField.text === ""
                        text: "Password for " + root.promptSsid
                        color: Style.muted
                        font: pwField.font
                    }
                }

                Rectangle {
                    id: goBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 36
                    radius: Style.radiusSmall
                    color: Style.accent
                    Text {
                        anchors.centerIn: parent
                        text: "\uf061"
                        color: Style.bg
                        font.family: Style.font
                        font.pixelSize: 15
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitPassword()
                    }
                }
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
                text: "Enter connect · W on/off · R rescan · right-click forget"
                color: Style.muted
                font.family: Style.font
                font.pixelSize: Style.fontSmall
            }
        }
    }
}
