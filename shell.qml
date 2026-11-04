import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "Plugins.js" as Plugins

// Run with: qs -p ~/Work/edge-panel
// Settings are in config.json and apply as soon as it is saved. The panel finds the
// Xeneon Edge by model unless config.json or EDGE_SCREEN names another monitor.
// Scaling is compensated so one layout pixel is one screen pixel.
PanelWindow {
  id: win

  readonly property string screenName: Quickshell.env("EDGE_SCREEN") || config.screen
  readonly property var focused: ToplevelManager.activeToplevel
  property var processes: []
  readonly property var plugin: Plugins.resolve(loader.plugins, focused ? focused.appId : "", focused ? focused.title : "", processes)
  // screen.devicePixelRatio rounds fractional scales up, so ask Hyprland for the real one.
  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
  readonly property real dpr: monitor && monitor.scale > 0 ? monitor.scale : 1

  screen: Quickshell.screens.find(s => screenName ? s.name === screenName : /XENEON EDGE/i.test(s.model))
    ?? Quickshell.screens[0]
  anchors.left: true
  anchors.bottom: true
  implicitWidth: 2560 / dpr
  implicitHeight: 720 / dpr
  color: Theme.background
  exclusionMode: ExclusionMode.Ignore

  // Never take keyboard focus, or tapping a button would defocus the app it controls.
  // On the Top layer, fullscreen windows such as the screensaver cover the panel.
  WlrLayershell.layer: config.aboveFullscreen ? WlrLayer.Overlay : WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.namespace: "edge-panel"

  onPluginChanged: pager.positionViewAtBeginning()
  onFocusedChanged: {
    processes = []
    inspectSoon.restart()
  }

  FileView {
    path: Quickshell.shellPath("config.json")
    watchChanges: true
    printErrors: false
    onFileChanged: reload()

    JsonAdapter {
      id: config

      property bool aboveFullscreen: false
      property int buttonColumns: 6
      property int buttonRows: 3
      property string screen: ""
    }
  }

  PluginLoader { id: loader }

  HomeAssistant { id: home }

  EdgeWindows {
    id: edgeWindows
    screen: win.screen
  }

  // Find what's running inside the focused window, as with herdr inside foot.
  Process {
    id: inspect
    command: ["sh", "-c", "hyprctl activewindow -j; echo ---; ps -eo pid=,ppid=,comm="]
    stdout: StdioCollector {
      onStreamFinished: win.processes = Plugins.windowProcesses(text)
    }
  }

  Timer {
    id: inspectSoon
    interval: 100
    onTriggered: inspect.running = true
  }

  // A terminal's title changes when a program starts or stops inside it.
  Connections {
    target: win.focused
    function onTitleChanged() { inspectSoon.restart() }
  }

  IpcHandler {
    target: "panel"

    function plugin(): string { return win.plugin.name }
    function page(): string { return win.plugin.pages[pager.currentIndex].name }
    function send(chord: string): void { Quickshell.execDetached(Plugins.wtypeArgs(chord)) }
    function pull(open: bool): void { pullDown.open = open }
    function swipe(index: int): void { pager.positionViewAtIndex(index, ListView.Beginning) }
    function menu(): void { edgeWindows.openMenu() }
    function home(open: bool): void { homeScreen.open = open }
  }

  Item {
    id: stage
    width: 2560
    height: 720
    scale: 1 / win.dpr
    transformOrigin: Item.TopLeft

    // Pull down from here for workspaces and media.
    Item {
      id: header
      width: parent.width
      height: 92

      Text {
        id: appIcon
        x: 32
        anchors.verticalCenter: parent.verticalCenter
        text: win.plugin.icon || ""
        color: Theme.accent
        font.family: Theme.font
        font.pixelSize: 52
      }

      Text {
        id: appName
        anchors.left: appIcon.right
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        text: win.plugin.name
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 44
        font.bold: true
      }

      Text {
        anchors.left: appName.right
        anchors.leftMargin: 28
        anchors.right: pill.left
        anchors.rightMargin: 40
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: win.focused ? win.focused.title : "No window focused"
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 30
      }

      Rectangle {
        id: pill
        anchors.centerIn: parent
        width: 160
        height: 10
        radius: 5
        color: Theme.textDim
      }

      MouseArea {
        anchors.fill: parent
        preventStealing: true
        onPositionChanged: mouse => pullDown.follow(mapToItem(stage, mouse.x, mouse.y).y)
        onReleased: pullDown.release()
        onClicked: pullDown.open = true
      }

      Text {
        id: pageTitle
        anchors.right: dots.left
        anchors.rightMargin: 28
        anchors.verticalCenter: parent.verticalCenter
        text: win.plugin.pages[Math.min(pager.currentIndex, win.plugin.pages.length - 1)].name
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 36
        font.bold: true
      }

      Row {
        id: dots
        anchors.right: homeButton.left
        anchors.rightMargin: 40
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Repeater {
          model: win.plugin.pages.length

          Rectangle {
            required property int index

            width: 22
            height: 22
            radius: 11
            color: index === pager.currentIndex ? Theme.accent : Theme.line
          }
        }
      }

      // Opens the Home Assistant screen, as does dragging in from the right edge.
      Text {
        id: homeButton
        anchors.right: closeMock.left
        anchors.rightMargin: 44
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F02DC}"
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 48

        MouseArea {
          anchors.fill: parent
          anchors.margins: -20
          onClicked: homeScreen.open = true
        }
      }

      // Only useful while the mock-up is covering part of a real monitor.
      Text {
        id: closeMock
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 40

        MouseArea {
          anchors.fill: parent
          anchors.margins: -20
          onClicked: Qt.quit()
        }
      }
    }

    // The whole of the rest belongs to the focused app, one swipeable page at a time.
    ListView {
      id: pager

      x: 28
      y: header.height
      width: parent.width - 56
      height: parent.height - y - 28
      orientation: ListView.Horizontal
      snapMode: ListView.SnapOneItem
      highlightRangeMode: ListView.StrictlyEnforceRange
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      model: win.plugin.pages

      delegate: PluginPage {
        required property var modelData
        required property int index

        page: modelData
        showing: index === pager.currentIndex
        gridColumns: Math.max(1, config.buttonColumns)
        gridRows: Math.max(1, config.buttonRows)
        width: pager.width
        height: pager.height
      }
    }

    // Drag in from the right edge for the Home Assistant screen.
    MouseArea {
      x: parent.width - width
      y: header.height
      width: 48
      height: parent.height - y
      preventStealing: true
      onPositionChanged: mouse => homeScreen.follow(mapToItem(stage, mouse.x, mouse.y).x)
      onReleased: homeScreen.release()
    }

    HomeScreen {
      id: homeScreen
      home: home
      gridColumns: Math.max(1, config.buttonColumns)
      gridRows: Math.max(1, config.buttonRows)
      width: parent.width
      height: parent.height
    }

    PullDown {
      id: pullDown
      windows: edgeWindows
      width: parent.width
      height: parent.height
    }
  }
}
