import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Always on screen: now playing and the system volume.
Rectangle {
  id: root

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0

  radius: Theme.radius
  color: Theme.surface
  border.color: Theme.line
  border.width: Theme.borderWidth
  Pixels {}

  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  Column {
    anchors.fill: parent
    anchors.margins: 28
    spacing: 22

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: root.player ? (root.player.trackTitle || "Unknown track") : "Nothing playing"
      color: Theme.text
      font.family: Theme.font
      font.pixelSize: 40
      font.bold: true
    }

    Text {
      width: parent.width
      elide: Text.ElideRight
      text: root.player ? (root.player.trackArtist || root.player.identity) : " "
      color: Theme.textDim
      font.family: Theme.font
      font.pixelSize: Theme.labelSize
    }

    Row {
      id: transport
      width: parent.width
      spacing: Theme.gap

      Repeater {
        model: [
          { icon: "", run: () => root.player && root.player.previous() },
          { icon: root.player && root.player.isPlaying ? "" : "", run: () => root.player && root.player.togglePlaying() },
          { icon: "", run: () => root.player && root.player.next() }
        ]

        Rectangle {
          required property var modelData

          width: (transport.width - 2 * Theme.gap) / 3
          height: 130
          radius: Theme.radius
          color: tap.pressed ? Theme.surfacePressed : Theme.background
          opacity: root.player ? 1 : 0.4

          Text {
            anchors.centerIn: parent
            text: parent.modelData.icon
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 60
          }

          MouseArea {
            id: tap
            anchors.fill: parent
            onClicked: parent.modelData.run()
          }
        }
      }
    }

    // Drag anywhere along the bar to set the volume.
    Item {
      width: parent.width
      height: 110

      Text {
        id: volumeIcon
        anchors.verticalCenter: parent.verticalCenter
        width: 96
        text: ""
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 56
      }

      Rectangle {
        id: track
        anchors.left: volumeIcon.right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 84
        radius: Theme.radius
        color: Theme.background

        Rectangle {
          width: track.width * Math.min(root.volume, 1)
          height: parent.height
          radius: Theme.radius
          color: Theme.accent
        }

        Text {
          anchors.centerIn: parent
          text: Math.round(root.volume * 100) + "%"
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: Theme.labelSize
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          preventStealing: true

          function apply(mouse) {
            if (root.sink && root.sink.audio) root.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
          }

          onPressed: mouse => apply(mouse)
          onPositionChanged: mouse => apply(mouse)
        }
      }
    }
  }
}
