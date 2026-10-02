//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import qs.modules

// Entry point. Waybar stays your bar, this config only hosts the pop-up menus.
// Run with:  qs -c menus        (config lives in ~/.config/quickshell/menus/)
ShellRoot {
    WallpaperPicker     { id: wallpaper }
    LiveWallpaperPicker { id: live }
    PowerMenu           { id: power }
    WifiMenu            { id: wifi }
    BluetoothMenu       { id: bluetooth }

    // qs -c menus ipc call <target> toggle|open|close
    IpcHandler {
        target: "wallpaper"
        function toggle(): void { wallpaper.toggle() }
        function open(): void   { wallpaper.show() }
        function close(): void  { wallpaper.close() }
    }
    IpcHandler {
        target: "live"
        function toggle(): void { live.toggle() }
        function open(): void   { live.show() }
        function close(): void  { live.close() }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { power.toggle() }
        function open(): void   { power.show() }
        function close(): void  { power.close() }
    }
    IpcHandler {
        target: "wifi"
        function toggle(): void { wifi.toggle() }
        function open(): void   { wifi.show() }
        function close(): void  { wifi.close() }
    }
    IpcHandler {
        target: "bluetooth"
        function toggle(): void { bluetooth.toggle() }
        function open(): void   { bluetooth.show() }
        function close(): void  { bluetooth.close() }
    }
}
