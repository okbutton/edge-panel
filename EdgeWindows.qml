import QtQuick
import Quickshell
import Quickshell.Hyprland

// Lets the Omarchy menu open on the Edge without leaving anything stranded there.
// The menu opens on the focused monitor, so focus moves to the Edge while it's open
// and returns when it closes. Any window that opens on the Edge (an app launched from
// the menu, say) is moved to the workspace in use before, as the panel would hide it.
Scope {
  id: root

  required property var screen

  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
  property string lastWorkspace: "1"
  property string returnWindow: ""
  property bool menuOpen: false

  function dispatch(lua) {
    Quickshell.execDetached(["hyprctl", "dispatch", lua])
  }

  function openMenu() {
    const toplevel = Hyprland.activeToplevel
    const address = toplevel ? String(toplevel.address || "") : ""
    returnWindow = !address ? "" : address.startsWith("0x") ? address : "0x" + address
    menuOpen = true
    Quickshell.execDetached(["sh", "-c",
      `hyprctl dispatch 'hl.dsp.focus({ monitor = "${monitor.name}" })' && omarchy menu summon`])
  }

  function goBack() {
    if (returnWindow) dispatch(`hl.dsp.focus({ window = "address:${returnWindow}" })`)
    else dispatch(`hl.dsp.focus({ workspace = "${lastWorkspace}" })`)
  }

  Connections {
    target: Hyprland

    function onFocusedWorkspaceChanged() {
      const workspace = Hyprland.focusedWorkspace
      if (workspace && root.monitor && workspace.monitor !== root.monitor) root.lastWorkspace = String(workspace.name)
    }

    function onRawEvent(event) {
      if (event.name === "closelayer" && event.data === "omarchy-menu" && root.menuOpen) {
        root.menuOpen = false
        root.goBack()
      } else if (event.name === "openwindow" && root.monitor && root.monitor.activeWorkspace) {
        // openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE
        const fields = event.data.split(",")
        if (fields[1] !== String(root.monitor.activeWorkspace.name)) return
        // The screensaver opens one window per monitor, the Edge included, and covers the panel.
        if (fields[2] === "org.omarchy.screensaver") return
        Quickshell.execDetached(["sh", "-c",
          `hyprctl dispatch 'hl.dsp.focus({ window = "address:0x${fields[0]}" })' && ` +
          `hyprctl dispatch 'hl.dsp.window.move({ workspace = "${root.lastWorkspace}" })'`])
      }
    }
  }
}
