pragma Singleton
import QtQuick
import Quickshell

// Shared look for every menu (wallpaper picker, Wi-Fi, Bluetooth, power...).
// Change a value here and all menus follow.
Singleton {
    // ---- Dracula palette ----
    readonly property color bg:        "#282A36"
    readonly property color surface:   "#44475A"
    readonly property color fg:        "#F8F8F2"
    readonly property color muted:     "#6272A4"
    readonly property color cyan:      "#8BE9FD"
    readonly property color green:     "#50FA7B"
    readonly property color orange:    "#FFB86C"
    readonly property color pink:      "#FF79C6"
    readonly property color purple:    "#BD93F9"
    readonly property color red:       "#FF5555"
    readonly property color yellow:    "#F1FA8C"

    // ---- Semantic colours (use these in menus) ----
    readonly property color accent:    purple
    readonly property color scrim:     Qt.alpha(bg, 0.55)
    readonly property color panel:     Qt.alpha(bg, 0.92)
    readonly property color outline:   Qt.alpha(fg, 0.12)

    // ---- Shape ----
    readonly property int radius:      22     // big cards
    readonly property int radiusSmall: 12     // pills, buttons
    readonly property int spacing:     14
    readonly property int borderWidth: 2

    // ---- Type ----
    readonly property string font:     "JetBrainsMono Nerd Font"
    readonly property int fontSmall:   12
    readonly property int fontNormal:  14
    readonly property int fontLarge:   18

    // ---- Motion (ms) ----
    readonly property int animFast:    150
    readonly property int animMed:     260
    readonly property int animSlow:    420
}
