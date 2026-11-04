import QtQml
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "Plugins.js" as Plugins

// Loads every plugins/*.json, and reloads when one is added, edited or removed.
// A broken file is reported and skipped, leaving the others working.
Scope {
  id: root

  property var byFile: ({})
  readonly property var plugins: Object.keys(byFile).sort().map(name => byFile[name])

  function store(name, text) {
    const next = Object.assign({}, byFile)
    try {
      next[name] = Plugins.parse(text)
    } catch (error) {
      console.warn(`Skipping plugin ${name}: ${error.message}`)
      delete next[name]
    }
    byFile = next
  }

  function forget(name) {
    const next = Object.assign({}, byFile)
    delete next[name]
    byFile = next
  }

  FolderListModel {
    id: folder
    folder: Qt.resolvedUrl("plugins")
    nameFilters: ["*.json"]
    showDirs: false
  }

  Instantiator {
    model: folder
    onObjectRemoved: (index, object) => root.forget(object.name)

    delegate: FileView {
      required property string fileName
      required property string filePath
      readonly property string name: fileName

      path: filePath
      watchChanges: true
      onFileChanged: reload()
      onLoaded: root.store(fileName, text())
    }
  }
}
