pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The panel's look, from the skin named in config.json ("skin"). A skin is a JSON file in
// skins/ that sets any of the keys in `defaults`; keys it leaves out come from its "base"
// (another skin, or "omarchy"), then from the defaults. The skin "omarchy", or a base of
// "omarchy", takes colours from Omarchy's current theme and changes when it does.
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
    iconSize: 72,
    borderWidth: 2,
    shadow: 0,
    pixelCorners: false,
    shadowColor: "@line"
  })

  // A skin's value for key, or the default. A value of "@name" means "the same as name",
  // so a skin can reuse its base's colours: "line": "@textDim".
  function value(key) {
    let v = skin[key] ?? defaults[key]
    for (let hops = 0; typeof v === "string" && v.startsWith("@") && hops < 4; hops++) {
      const other = v.slice(1)
      v = skin[other] ?? defaults[other]
    }
    return v
  }

  property string skinName: "matte-black"
  // config.json "backgroundOpacity": 0 shows the wallpaper bare, 1 hides it.
  property real backgroundOpacity: 1
  readonly property bool seeThrough: backgroundOpacity < 1
  // The panel's own background, letting the wallpaper show through.
  readonly property color panelBackground: Qt.rgba(background.r, background.g, background.b, backgroundOpacity)
  // config.json "tileOpacity": buttons, tiles and cards are the skin's surface colour at this
  // opacity, so the wallpaper glows faintly through them like Omarchy's terminals. 1 is solid.
  property real tileOpacity: 0.85
  property var own: ({})
  property var base: ({})
  readonly property string baseName: skinName === "omarchy" ? "omarchy" : own.base || ""
  readonly property var skin: Object.assign({}, base, own)

  readonly property color background: value("background")
  readonly property color solidSurface: value("surface")
  readonly property color solidSurfacePressed: value("surfacePressed")
  readonly property color surface: Qt.rgba(solidSurface.r, solidSurface.g, solidSurface.b, tileOpacity)
  readonly property color surfacePressed: Qt.rgba(solidSurfacePressed.r, solidSurfacePressed.g, solidSurfacePressed.b, tileOpacity)
  // Wells set into a card (media buttons, the volume track): the background colour, as see-through as tiles.
  readonly property color inset: Qt.rgba(background.r, background.g, background.b, tileOpacity)
  readonly property color line: value("line")
  readonly property color text: value("text")
  readonly property color textDim: value("textDim")
  readonly property color accent: value("accent")
  readonly property color danger: value("danger")
  readonly property color shadowColor: value("shadowColor")

  readonly property string font: value("font")
  readonly property int radius: value("radius")
  readonly property int gap: value("gap")
  readonly property int labelSize: value("labelSize")
  readonly property int detailSize: value("detailSize")
  readonly property int iconSize: value("iconSize")

  // Pixel-art touches: border thickness, a hard drop shadow offset (0 for none), and
  // corners stepped one border-width in instead of rounded. See Pixels.qml.
  readonly property int borderWidth: value("borderWidth")
  readonly property int shadow: value("shadow")
  readonly property bool pixelCorners: value("pixelCorners")

  readonly property bool followsOmarchy: baseName === "omarchy"
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
    // Some themes (Solitude) make their lighter background the background itself; then
    // buttons use the selection colour so they still stand out.
    let surface = light ? c.dark_background : c.lighter_background
    const flat = !surface || surface.toLowerCase() === (c.background || "").toLowerCase()
    if (flat) surface = c.selection
    const out = {
      background: c.background,
      surface: surface,
      surfacePressed: flat ? c.muted : c.selection,
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
        const config = JSON.parse(text())
        root.skinName = config.skin || "matte-black"
        const opacity = Number(config.backgroundOpacity ?? 1)
        root.backgroundOpacity = isNaN(opacity) ? 1 : Math.max(0, Math.min(1, opacity))
        const tiles = Number(config.tileOpacity ?? 0.85)
        root.tileOpacity = isNaN(tiles) ? 0.85 : Math.max(0, Math.min(1, tiles))
      } catch (error) {
        root.skinName = "matte-black"
        root.backgroundOpacity = 1
        root.tileOpacity = 0.85
      }
    }
  }

  // The skin's own file ("omarchy" has none: it is all base).
  FileView {
    path: root.skinName === "omarchy" ? "" : Quickshell.shellPath(`skins/${root.skinName}.json`)
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onPathChanged: if (!path) root.own = {}
    onLoaded: {
      try {
        root.own = JSON.parse(text())
      } catch (error) {
        console.warn(`Skin ${root.skinName}: ${error.message}`)
        root.own = {}
      }
    }
    onLoadFailed: {
      console.warn(`Skin ${root.skinName} not found, using the default look`)
      root.own = {}
    }
  }

  // The skin it builds on: Omarchy's colours, or another skin's file.
  FileView {
    id: baseFile

    path: root.followsOmarchy ? root.omarchyDir + "/theme/colors.toml"
      : root.baseName ? Quickshell.shellPath(`skins/${root.baseName}.json`) : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onPathChanged: if (!path) root.base = {}
    onLoaded: {
      try {
        const values = root.followsOmarchy ? root.fromOmarchy(text()) : JSON.parse(text())
        delete values.base
        root.base = values
      } catch (error) {
        console.warn(`Skin base ${root.baseName}: ${error.message}`)
        root.base = {}
      }
    }
    onLoadFailed: {
      console.warn(`Skin base ${root.baseName} not found`)
      root.base = {}
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
      baseFile.reload()
    }
  }
}
