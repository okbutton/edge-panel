import QtQuick
import Quickshell
import Quickshell.Io
import "Home.js" as Home

// Talks to Home Assistant, using the URL and token in home.json. States and service calls
// go over the REST API. The registries, the energy dashboard's settings and statistics
// come over the websocket API, through ha-ws.py.
// Pages come from home.json, or from Home Assistant's areas if it lists none.
// Nothing is polled unless the home screen is showing.
Scope {
  id: root

  property bool active: false
  property int perPage: 18

  property var states: ({})
  property var areaPages: []
  property var energySources: []
  property var energy: []
  property string error: ""
  readonly property bool configured: !!settings.url && !!settings.token
  readonly property bool showEnergy: settings.energy !== false && energySources.length > 0
  readonly property var pages: Home.buildPages(settings.pages.length ? settings.pages : areaPages, states, perPage)

  function request(method, path, body, done) {
    const xhr = new XMLHttpRequest()
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (xhr.status >= 200 && xhr.status < 300) {
        root.error = ""
        if (done) done(xhr.responseText)
      } else {
        root.error = xhr.status === 401 ? "Home Assistant refused the token in home.json"
          : xhr.status === 0 ? `Can't reach ${settings.url}`
          : `Home Assistant replied ${xhr.status}`
      }
    }
    xhr.open(method, settings.url.replace(/\/$/, "") + path)
    xhr.setRequestHeader("Authorization", "Bearer " + settings.token)
    xhr.setRequestHeader("Content-Type", "application/json")
    xhr.send(body ? JSON.stringify(body) : null)
  }

  function refresh() {
    if (!configured) return
    request("GET", "/api/states", null, text => {
      const next = {}
      for (const state of JSON.parse(text)) next[state.entity_id] = state
      root.states = next
    })
  }

  // The registries and energy settings change rarely: read them on loading, and each
  // time the home screen opens.
  function load() {
    if (!configured || registries.running) return
    registries.command = ["python3", Quickshell.shellPath("ha-ws.py"), JSON.stringify([
      { type: "energy/get_prefs" },
      { type: "config/area_registry/list" },
      { type: "config/device_registry/list" },
      { type: "config/entity_registry/list" }
    ])]
    registries.running = true
  }

  function loadStatistics() {
    if (!configured || !showEnergy || statistics.running) return
    const midnight = new Date()
    midnight.setHours(0, 0, 0, 0)
    statistics.command = ["python3", Quickshell.shellPath("ha-ws.py"),
      JSON.stringify(Home.statisticsCommands(energySources, midnight.toISOString()))]
    statistics.running = true
  }

  function press(tile) {
    if (!tile.service) return
    const data = Object.assign({ entity_id: tile.entity }, tile.data || {})
    request("POST", `/api/services/${tile.service[0]}/${tile.service[1]}`, data, () => refreshSoon.restart())
  }

  function reset() {
    states = {}
    areaPages = []
    energySources = []
    energy = []
    load()
    refresh()
  }

  onActiveChanged: if (active) load()
  onEnergySourcesChanged: loadStatistics()

  FileView {
    path: Quickshell.shellPath("home.json")
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.reset()

    JsonAdapter {
      id: settings

      property string url: ""
      property string token: ""
      property var pages: []
      property var energy: true
    }
  }

  Process {
    id: registries
    environment: ({ HA_URL: settings.url, HA_TOKEN: settings.token })
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const reply = JSON.parse(text)
          if (reply.error) throw new Error(reply.error)
          root.energySources = Home.energySources(reply[0])
          root.areaPages = Home.areaPages(reply[1], reply[2], reply[3])
        } catch (error) {
          console.warn(`Home Assistant websocket: ${error.message}`)
        }
      }
    }
  }

  Process {
    id: statistics
    environment: ({ HA_URL: settings.url, HA_TOKEN: settings.token })
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const reply = JSON.parse(text)
          if (reply.error) throw new Error(reply.error)
          root.energy = Home.readStatistics(root.energySources, reply)
        } catch (error) {
          console.warn(`Home Assistant statistics: ${error.message}`)
        }
      }
    }
  }

  Timer {
    interval: 2000
    running: root.active && root.configured
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Home Assistant compiles statistics every five minutes, so once a minute keeps up.
  Timer {
    interval: 60000
    running: root.active && root.showEnergy
    repeat: true
    triggeredOnStart: true
    onTriggered: root.loadStatistics()
  }

  Timer {
    id: refreshSoon
    interval: 400
    onTriggered: root.refresh()
  }
}
