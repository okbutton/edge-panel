import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Slides down over the app controls: workspaces, system controls and media, whichever
// app has focus. Dragged open from the header in shell.qml, and shut from the grip
// along its bottom.
Rectangle {
  id: root

  required property var windows

  property bool open: false
  property bool dragging: false
  property real dragY: 0
  property var toggles: ({})

  // "toggle" names a key in the status output below, which lights the button when on.
  readonly property var controls: [
    { icon: "", label: "Menu", menu: true },
    { icon: "", label: "Stay awake", run: ["omarchy", "toggle", "idle", "toggle"], toggle: "awake" },
    { icon: "", label: "Night light", run: ["omarchy", "toggle", "nightlight"], toggle: "night" },
    { icon: "", label: "Do not disturb", run: ["omarchy", "toggle", "notification", "silencing"], toggle: "dnd" },
    { icon: "", label: "Mic mute", run: ["omarchy", "audio", "input", "mute"], toggle: "mic" },
    { icon: "", label: "Audio output", run: ["omarchy", "audio", "output", "switch"] },
    { icon: "", label: "Screenshot", run: ["omarchy", "capture", "screenshot"], close: true },
    { icon: "", label: "Lock", run: ["omarchy", "system", "lock"], close: true, confirm: true }
  ]

  // Follows a finger while dragging, then settles open or shut.
  function follow(stageY) {
    dragging = true
    dragY = Math.max(0, Math.min(height, stageY))
  }

  function release() {
    if (!dragging) return
    open = dragY > height / 2
    dragging = false
  }

  function press(control) {
    if (control.close || control.menu) open = false
    if (control.menu) windows.openMenu()
    else Quickshell.execDetached(control.run)
    if (control.toggle) refreshSoon.restart()
  }

  y: dragging ? dragY - height : (open ? 0 : -height)
  color: Theme.background
  visible: y > -height

  Behavior on y {
    enabled: !root.dragging
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Process {
    id: status
    command: ["sh", "-c", `
      echo "awake=$(omarchy toggle idle status | jq -r 'if .enabled then "on" else "off" end')"
      echo "night=$(omarchy toggle nightlight --status | jq -r 'if .enabled then "on" else "off" end')"
      echo "dnd=$(omarchy-shell notifications isDnd)"
      wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED && echo mic=on || echo mic=off
    `]
    stdout: StdioCollector {
      onStreamFinished: {
        const next = {}
        for (const line of text.split("\n")) {
          const [key, value] = line.split("=")
          if (key) next[key] = value === "on"
        }
        root.toggles = next
      }
    }
  }

  Timer {
    interval: 3000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: status.running = true
  }

  Timer {
    id: refreshSoon
    interval: 600
    onTriggered: status.running = true
  }

  Item {
    id: left
    x: 28
    y: 24
    width: 1480
    height: parent.height - grip.height - 44

    Text {
      id: workspacesTitle
      text: "Workspaces"
      color: Theme.textDim
      font.family: Theme.font
      font.pixelSize: 30
      font.bold: true
    }

    Row {
      id: workspaces
      anchors.top: workspacesTitle.bottom
      anchors.topMargin: 12
      width: parent.width
      height: 140
      spacing: Theme.gap

      Repeater {
        model: [1, 2, 3, 4, 5, 6]

        Rectangle {
          required property int modelData
          // The focused window's workspace: touching the Edge focuses the Edge's own monitor.
          readonly property bool current: !!Hyprland.activeToplevel && !!Hyprland.activeToplevel.workspace
            && Hyprland.activeToplevel.workspace.id === modelData
          // Showing on a monitor, though not the focused one.
          readonly property bool visibleElsewhere: Hyprland.monitors.values.some(m => m.activeWorkspace && m.activeWorkspace.id === modelData)

          width: (workspaces.width - 5 * workspaces.spacing) / 6
          height: workspaces.height
          radius: Theme.radius
          color: current ? Theme.accent : Theme.surface
          border.color: visibleElsewhere && !current ? Theme.accent : Theme.line
          border.width: 3

          Text {
            anchors.centerIn: parent
            text: parent.modelData
            color: parent.current ? Theme.background : Theme.text
            font.family: Theme.font
            font.pixelSize: 64
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            onClicked: Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = "${parent.modelData}" })`])
          }
        }
      }
    }

    Text {
      id: systemTitle
      anchors.top: workspaces.bottom
      anchors.topMargin: 24
      text: "System"
      color: Theme.textDim
      font.family: Theme.font
      font.pixelSize: 30
      font.bold: true
    }

    Grid {
      id: system
      anchors.top: systemTitle.bottom
      anchors.topMargin: 12
      anchors.bottom: parent.bottom
      width: parent.width
      columns: 4
      spacing: Theme.gap

      Repeater {
        model: root.controls

        ActionButton {
          required property var modelData

          // ActionButton runs commands itself; route through press() for the menu and toggles.
          action: Object.assign({}, modelData, { run: null, active: !!root.toggles[modelData.toggle] })
          onTriggered: root.press(modelData)
          width: (system.width - 3 * system.spacing) / 4
          height: (system.height - system.spacing) / 2
        }
      }
    }
  }

  MediaCard {
    x: left.x + left.width + 28
    y: 24
    width: parent.width - x - 28
    height: parent.height - grip.height - 44
  }

  Rectangle {
    id: grip
    anchors.bottom: parent.bottom
    width: parent.width
    height: 84
    color: Theme.surface

    Rectangle {
      anchors.centerIn: parent
      width: 160
      height: 10
      radius: 5
      color: Theme.textDim
    }

    MouseArea {
      anchors.fill: parent
      preventStealing: true
      onPositionChanged: mouse => root.follow(mapToItem(root.parent, mouse.x, mouse.y).y)
      onReleased: root.release()
      onClicked: root.open = false
    }
  }
}
