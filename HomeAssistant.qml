import QtQuick
import Quickshell
import Quickshell.Io
import "Home.js" as Home

// Talks to Home Assistant over its REST API, using the URL and token in home.json.
// Pages come from home.json, or from Home Assistant's areas if it lists none.
// States are polled only while the home screen is showing.
Scope {
  id: root

  property bool active: false
  property int perPage: 18

  property var states: ({})
  property var areaPages: []
  property string error: ""
  readonly property bool configured: !!settings.url && !!settings.token
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

  function loadAreas() {
    if (!configured || settings.pages.length) return
    request("POST", "/api/template", { template: Home.areaTemplate }, text => {
      root.areaPages = JSON.parse(text).map(page => ({
        name: page.name, entities: page.entities.filter(Home.isSupported).sort()
      }))
    })
  }

  function press(tile) {
    if (!tile.service) return
    const data = Object.assign({ entity_id: tile.entity }, tile.data || {})
    request("POST", `/api/services/${tile.service[0]}/${tile.service[1]}`, data, () => refreshSoon.restart())
  }

  onActiveChanged: if (active && areaPages.length === 0) loadAreas()
  onConfiguredChanged: {
    areaPages = []
    loadAreas()
    refresh()
  }

  FileView {
    path: Quickshell.shellPath("home.json")
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.areaPages = []
      root.loadAreas()
      root.refresh()
    }

    JsonAdapter {
      id: settings

      property string url: ""
      property string token: ""
      property var pages: []
    }
  }

  Timer {
    interval: 2000
    running: root.active && root.configured
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshSoon
    interval: 400
    onTriggered: root.refresh()
  }
}
