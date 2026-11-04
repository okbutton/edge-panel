import QtQuick
import QtQml.Models as Models
import Quickshell
import Quickshell.Io

// This computer at a glance: CPU, memory, GPU, network and disks, with the last two
// minutes of each as a graph. Opened from the chip in the panel's header. sysinfo.py
// takes the readings, and runs only while this screen is showing.
SideScreen {
  id: root

  property var info: null
  property var history: ({ cpu: [], memory: [], gpu: [], down: [], up: [] })
  readonly property int historyLength: 60

  readonly property var cpu: info ? info.cpu : null
  readonly property var memory: info ? info.memory : null
  readonly property var gpu: info ? info.gpu : null
  readonly property var network: info ? info.network : null

  function bytes(value) {
    const units = ["B", "KB", "MB", "GB", "TB"]
    let unit = 0
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024
      unit++
    }
    return `${value.toFixed(value >= 100 || unit === 0 ? 0 : 1)} ${units[unit]}`
  }

  function rate(value) {
    return bytes(value) + "/s"
  }

  function degrees(value) {
    return value === null || value === undefined ? "" : `${Math.round(value)}°`
  }

  function duration(seconds) {
    const days = Math.floor(seconds / 86400)
    const hours = Math.floor(seconds % 86400 / 3600)
    const minutes = Math.floor(seconds % 3600 / 60)
    return days ? `${days}d ${hours}h` : hours ? `${hours}h ${minutes}m` : `${minutes}m`
  }

  function show(index) {
    open = true
    pager.positionViewAtIndex(index, ListView.Beginning)
  }

  function record(next) {
    const add = (series, value) => series.concat([value]).slice(-historyLength)
    history = {
      cpu: add(history.cpu, next.cpu.usage),
      memory: add(history.memory, 100 * next.memory.used / next.memory.total),
      gpu: next.gpu ? add(history.gpu, next.gpu.usage || 0) : [],
      down: add(history.down, next.network.down),
      up: add(history.up, next.network.up)
    }
    info = next
  }

  title: "System"
  icon: "\u{F061A}"

  readonly property var pageNames: ["Overview", "Processes"]

  tabs: Row {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    spacing: 40

    Repeater {
      model: root.pageNames

      Text {
        required property string modelData
        required property int index

        text: modelData
        color: index === pager.currentIndex ? Theme.accent : Theme.textDim
        font.family: Theme.font
        font.pixelSize: 34
        font.bold: index === pager.currentIndex

        MouseArea {
          anchors.fill: parent
          anchors.margins: -16
          onClicked: pager.positionViewAtIndex(parent.index, ListView.Beginning)
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - x
      leftPadding: 20
      elide: Text.ElideRight
      text: root.info ? `${root.info.host}  ·  ${root.cpu.model}  ·  up ${root.duration(root.info.uptime)}` : ""
      color: Theme.textDim
      font.family: Theme.font
      font.pixelSize: 30
    }
  }

  Process {
    running: root.visible
    command: ["python3", Quickshell.shellPath("sysinfo.py"), "2"]
    stdout: SplitParser {
      onRead: line => {
        try {
          root.record(JSON.parse(line))
        } catch (error) {
          console.warn(`sysinfo.py: ${error.message}`)
        }
      }
    }
  }

  component Card: Rectangle {
    id: card

    property string title
    property string value
    property string detail
    default property alias content: extra.data

    width: (cards.width - 4 * cards.spacing) / 5
    height: cards.height
    radius: Theme.radius
    color: Theme.surface
    border.color: Theme.line
    border.width: 2

    Column {
      id: heading
      x: 28
      y: 22
      width: parent.width - 56
      spacing: 4

      Text {
        text: card.title
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 30
      }

      Text {
        width: parent.width
        elide: Text.ElideRight
        text: card.value
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 56
        font.bold: true
      }

      Text {
        width: parent.width
        elide: Text.ElideRight
        text: card.detail
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: Theme.detailSize
      }
    }

    Item {
      id: extra
      x: 28
      anchors.top: heading.bottom
      anchors.topMargin: 20
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 24
      width: parent.width - 56
    }
  }

  // A labelled bar, for a share of something: memory, VRAM, a disk.
  component Meter: Column {
    id: meter

    property string label
    property string amount
    property real fraction: 0

    width: parent.width
    spacing: 8

    Item {
      width: parent.width
      height: labelText.height

      Text {
        id: labelText
        width: parent.width - amountText.width - 16
        elide: Text.ElideRight
        text: meter.label
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 26
      }

      Text {
        id: amountText
        anchors.right: parent.right
        text: meter.amount
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 26
      }
    }

    Rectangle {
      width: parent.width
      height: 16
      radius: 8
      color: Theme.surfacePressed

      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, meter.fraction))
        height: parent.height
        radius: 8
        color: meter.fraction > 0.9 ? Theme.danger : Theme.accent
      }
    }
  }

  ListView {
    id: pager

    anchors.fill: parent
    visible: !!root.info
    orientation: ListView.Horizontal
    snapMode: ListView.SnapOneItem
    highlightRangeMode: ListView.StrictlyEnforceRange
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    model: Models.ObjectModel {
  Row {
    id: cards
    width: pager.width
    height: pager.height
    spacing: Theme.gap

    Card {
      title: "CPU"
      value: root.cpu ? `${Math.round(root.cpu.usage)}%` : ""
      detail: root.cpu ? [root.degrees(root.cpu.temperature),
        root.cpu.frequency ? `${root.cpu.frequency.toFixed(2)} GHz` : "",
        `load ${root.cpu.load.toFixed(2)}`].filter(part => part).join(" · ") : ""

      // One bar per core, above the graph.
      Row {
        id: cores
        width: parent.width
        height: 70
        spacing: 4

        Repeater {
          model: root.cpu ? root.cpu.cores : []

          Rectangle {
            required property real modelData

            width: (cores.width - (root.cpu.cores.length - 1) * cores.spacing) / root.cpu.cores.length
            height: cores.height
            radius: 3
            color: Theme.surfacePressed

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: Math.max(3, parent.height * parent.modelData / 100)
              radius: 3
              color: Theme.accent
            }
          }
        }
      }

      Graph {
        anchors.top: cores.bottom
        anchors.topMargin: 20
        anchors.bottom: parent.bottom
        width: parent.width
        values: root.history.cpu
        length: root.historyLength
      }
    }

    Card {
      title: "Memory"
      value: root.memory ? `${Math.round(100 * root.memory.used / root.memory.total)}%` : ""
      detail: root.memory ? `${root.bytes(root.memory.used)} of ${root.bytes(root.memory.total)}` : ""

      Meter {
        id: swap
        visible: !!root.memory && root.memory.swapTotal > 0
        label: "Swap"
        amount: root.memory ? `${root.bytes(root.memory.swapUsed)} of ${root.bytes(root.memory.swapTotal)}` : ""
        fraction: root.memory && root.memory.swapTotal ? root.memory.swapUsed / root.memory.swapTotal : 0
      }

      Graph {
        anchors.top: swap.bottom
        anchors.topMargin: 20
        anchors.bottom: parent.bottom
        width: parent.width
        values: root.history.memory
        length: root.historyLength
      }
    }

    Card {
      title: root.gpu ? `GPU  ·  ${root.gpu.name}` : "GPU"
      value: root.gpu && root.gpu.usage !== null ? `${Math.round(root.gpu.usage)}%` : "–"
      detail: root.gpu ? [root.degrees(root.gpu.temperature),
        root.gpu.power ? `${Math.round(root.gpu.power)} W` : ""].filter(part => part).join(" · ") : "Not found"

      Meter {
        id: vram
        visible: !!root.gpu && root.gpu.memTotal > 0
        label: "VRAM"
        amount: root.gpu ? `${root.bytes(root.gpu.memUsed)} of ${root.bytes(root.gpu.memTotal)}` : ""
        fraction: root.gpu && root.gpu.memTotal ? root.gpu.memUsed / root.gpu.memTotal : 0
      }

      Graph {
        anchors.top: vram.bottom
        anchors.topMargin: 20
        anchors.bottom: parent.bottom
        width: parent.width
        values: root.history.gpu
        length: root.historyLength
      }
    }

    Card {
      title: "Network"
      value: root.network ? `\u{F0045} ${root.rate(root.network.down)}` : ""
      detail: root.network ? `\u{F005D} ${root.rate(root.network.up)}` : ""

      Text {
        id: address
        width: parent.width
        elide: Text.ElideRight
        text: root.network ? `${root.network.interface}  ${root.network.address}` : ""
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 26
      }

      // Download filled, upload as a line, on one scale.
      Graph {
        anchors.top: address.bottom
        anchors.topMargin: 20
        anchors.bottom: parent.bottom
        width: parent.width
        values: root.history.down
        second: root.history.up
        maximum: Math.max(1024, ...root.history.down, ...root.history.up)
        length: root.historyLength
      }
    }

    Card {
      title: "Disks"
      value: root.info ? `\u{F0045} ${root.rate(root.info.io.read)}` : ""
      detail: root.info ? `\u{F005D} ${root.rate(root.info.io.write)}` : ""

      Column {
        width: parent.width
        spacing: 22

        Repeater {
          model: root.info ? root.info.disks : []

          Meter {
            required property var modelData

            label: modelData.mount
            amount: `${root.bytes(modelData.used)} of ${root.bytes(modelData.total)}`
            fraction: modelData.total ? modelData.used / modelData.total : 0
          }
        }
      }
    }
  }

  // The busiest processes since the last reading, in two columns.
  Grid {
    id: processes
    width: pager.width
    height: pager.height
    flow: Grid.TopToBottom
    rows: 6
    columns: 2
    spacing: Theme.gap

    readonly property real rowWidth: (width - spacing) / 2
    readonly property real rowHeight: (height - 5 * spacing) / 6

    Repeater {
      model: root.info ? root.info.processes : []

      Rectangle {
        required property var modelData

        width: processes.rowWidth
        height: processes.rowHeight
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.line
        border.width: 2
        clip: true

        // How busy, as a share of one core.
        Rectangle {
          width: parent.width * Math.min(1, parent.modelData.cpu / 100)
          height: parent.height
          radius: Theme.radius
          color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
        }

        Text {
          id: processName
          x: 28
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - details.width - 40
          elide: Text.ElideRight
          text: parent.modelData.name
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: 34
          font.bold: true
        }

        Text {
          id: details
          anchors.right: cpuText.left
          anchors.rightMargin: 36
          anchors.verticalCenter: parent.verticalCenter
          // One process shows its ID; several of the same name show how many there are.
          text: `${root.bytes(parent.modelData.memory)}  ·  ${parent.modelData.count > 1 ? parent.modelData.count + " processes" : parent.modelData.pid}`
          color: Theme.textDim
          font.family: Theme.font
          font.pixelSize: 26
        }

        Text {
          id: cpuText
          anchors.right: parent.right
          anchors.rightMargin: 28
          anchors.verticalCenter: parent.verticalCenter
          width: 150
          horizontalAlignment: Text.AlignRight
          text: `${parent.modelData.cpu.toFixed(1)}%`
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: 38
          font.bold: true
        }
      }
    }
  }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: !root.info
    text: "Reading…"
    color: Theme.textDim
    font.family: Theme.font
    font.pixelSize: Theme.labelSize
  }
}
