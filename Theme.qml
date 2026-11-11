pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The panel's look, from the skin named in config.json ("skin"). A skin is a JSON file in
// skins/ that sets any of the keys in `defaults`; keys it leaves out keep their default.
// The skin "omarchy" follows Omarchy's current theme instead, changing when it does.
// Sizes are Edge pixels. The panel is about 184 pixels per inch, so 7 px is 1 mm.
Singleton {
  id: root

  // Matte Black, from /usr/share/omarchy/themes/matte-black/colors.toml.
  readonly property var defaults: ({
    background: "#090909",
    surface: "#161616",
    surfacePressed: "#2a2a2a",
    line: "#333333",
    text: "#eaeaea",
    textDim: "#8a8a8d",
    accent: "#e68e0d",
    danger: "#D35F5F",
    font: "JetBrainsMono Nerd Font",
    radius: 20,
    gap: 16,
    labelSize: 32,
    detailSize: 26,
    iconSize: 72
  })

  property string skinName: "matte-black"
  property var skin: ({})

  readonly property color background: skin.background ?? defaults.background
  readonly property color surface: skin.surface ?? defaults.surface
  readonly property color surfacePressed: skin.surfacePressed ?? defaults.surfacePressed
  readonly property color line: skin.line ?? defaults.line
  readonly property color text: skin.text ?? defaults.text
  readonly property color textDim: skin.textDim ?? defaults.textDim
  readonly property color accent: skin.accent ?? defaults.accent
  readonly property color danger: skin.danger ?? defaults.danger

  readonly property string font: skin.font ?? defaults.font
  readonly property int radius: skin.radius ?? defaults.radius
  readonly property int gap: skin.gap ?? defaults.gap
  readonly property int labelSize: skin.labelSize ?? defaults.labelSize
  readonly property int detailSize: skin.detailSize ?? defaults.detailSize
  readonly property int iconSize: skin.iconSize ?? defaults.iconSize

  readonly property bool followsOmarchy: skinName === "omarchy"
  readonly property string omarchyDir: Quickshell.env("HOME") + "/.local/state/omarchy/current"

  // Omarchy's colors.toml, as panel colours. Dark themes lift buttons above the background
  // and light themes sink them below it, as Omarchy's own apps do.
  function fromOmarchy(toml) {
    const c = {}
    for (const line of toml.split("\n")) {
      const match = line.match(/^\s*([a-z_]+)\s*=\s*"([^"]*)"/)
      if (match) c[match[1]] = match[2]
    }
    const light = /^\s*mode\s*=\s*"light"/m.test(toml)
    const out = {
      background: c.background,
      surface: light ? c.dark_background : c.lighter_background,
      surfacePressed: c.selection,
      line: c.muted,
      text: c.foreground,
      textDim: c.light_foreground,
      accent: c.accent,
      danger: c.red
    }
    for (const key in out) if (!out[key]) delete out[key]
    return out
  }

  FileView {
    path: Quickshell.shellPath("config.json")
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.skinName = JSON.parse(text()).skin || "matte-black"
      } catch (error) {
        root.skinName = "matte-black"
      }
    }
  }

  FileView {
    id: skinFile

    path: root.followsOmarchy ? root.omarchyDir + "/theme/colors.toml"
      : Quickshell.shellPath(`skins/${root.skinName}.json`)
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.skin = root.followsOmarchy ? root.fromOmarchy(text()) : JSON.parse(text())
      } catch (error) {
        console.warn(`Skin ${root.skinName}: ${error.message}`)
        root.skin = {}
      }
    }
    onLoadFailed: {
      console.warn(`Skin ${root.skinName} not found, using the default look`)
      root.skin = {}
    }
  }

  // Omarchy replaces the theme folder when switching themes, which can lose the watch on
  // colors.toml, so the theme's name changing reloads it too.
  FileView {
    path: root.followsOmarchy ? root.omarchyDir + "/theme.name" : ""
    watchChanges: true
    printErrors: false
    onFileChanged: {
      reload()
      skinFile.reload()
    }
  }
}
