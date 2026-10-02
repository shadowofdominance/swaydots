import QtQuick
import Quickshell.Io

// Run one command, get (exitCode, output) in a callback.
//   runner.run(["nmcli", "radio", "wifi"], (code, out) => { ... })
// stderr is merged into the output. If you call run() while it is busy,
// the new call is queued and starts as soon as the current one ends.
Process {
    id: p

    property var callback: null
    property var pending: null

    function run(cmd, cb) {
        if (running) {
            pending = { cmd: cmd, cb: cb }
            return
        }
        callback = cb || null
        command = ["sh", "-c",
                   'out=$("$@" 2>&1); c=$?; printf "%s\\n__EXIT__%s\\n" "$out" "$c"',
                   "sh"].concat(cmd)
        running = true
    }

    onRunningChanged: {
        if (!running && pending) {
            const q = pending
            pending = null
            run(q.cmd, q.cb)
        }
    }

    stdout: StdioCollector {
        id: collector
        onStreamFinished: {
            const t = collector.text
            const i = t.lastIndexOf("__EXIT__")
            const code = i >= 0 ? parseInt(t.slice(i + 8)) : -1
            const body = (i >= 0 ? t.slice(0, i) : t).replace(/\s+$/, "")
            const cb = p.callback
            p.callback = null
            if (cb) cb(code, body)
        }
    }
}
