pragma Singleton

import QtQuick
import Quickshell

// Matte Black palette, from /usr/share/omarchy/themes/matte-black/colors.toml.
// Sizes are Edge pixels. The panel is about 184 pixels per inch, so 7 px is 1 mm.
Singleton {
  readonly property color background: "#090909"
  readonly property color surface: "#161616"
  readonly property color surfacePressed: "#2a2a2a"
  readonly property color line: "#333333"
  readonly property color text: "#eaeaea"
  readonly property color textDim: "#8a8a8d"
  readonly property color accent: "#e68e0d"
  readonly property color danger: "#D35F5F"

  readonly property string font: "JetBrainsMono Nerd Font"
  readonly property int radius: 20
  readonly property int gap: 16
  readonly property int labelSize: 32
  readonly property int detailSize: 26
  readonly property int iconSize: 72
}
