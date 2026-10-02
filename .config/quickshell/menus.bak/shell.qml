//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import qs.modules

// Entry point. Waybar stays your bar, this config only hosts the pop-up menus.
// Run with:  qs -c menus        (config lives in ~/.config/quickshell/menus/)
ShellRoot {
    WallpaperPicker { id: wallpaper }
    PowerMenu       { id: power }

    // qs -c menus ipc call wallpaper toggle
    IpcHandler {
        target: "wallpaper"
        function toggle(): void { wallpaper.toggle() }
        function open(): void   { wallpaper.show() }
        function close(): void  { wallpaper.close() }
    }

    // qs -c menus ipc call power toggle
    IpcHandler {
        target: "power"
        function toggle(): void { power.toggle() }
        function open(): void   { power.show() }
        function close(): void  { power.close() }
    }

    // Later: WifiMenu / BluetoothMenu get added here the same way.
}
