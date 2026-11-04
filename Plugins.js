.pragma library

// Every plugin gets this page last, unless it sets "windowPage": false.
const windowPage = {
  name: "Window",
  actions: [
    { icon: "", label: "Fullscreen", hypr: 'hl.dsp.window.fullscreen({ mode = "fullscreen" })' },
    { icon: "", label: "Maximise", hypr: 'hl.dsp.window.fullscreen({ mode = "maximized" })' },
    { icon: "", label: "Float", hypr: 'hl.dsp.window.float({ action = "toggle" })' },
    { icon: "", label: "Split", hypr: 'hl.dsp.layout("togglesplit")' },
    { icon: "", label: "Close", hypr: "hl.dsp.window.close()", danger: true, confirm: true }
  ]
}

const fallback = { name: "Desktop", icon: "", pages: [windowPage], score: 0 }

// Turns a plugin file's text into a plugin. Throws if it can't be used.
function parse(text) {
  const plugin = JSON.parse(text)
  if (!plugin.name) throw new Error("missing name")
  if (!Array.isArray(plugin.pages)) throw new Error("missing pages")

  const match = plugin.match || {}
  plugin.appPattern = match.app ? new RegExp(match.app, "i") : null
  plugin.titlePattern = match.title ? new RegExp(match.title) : null
  plugin.process = match.process || null
  if (plugin.windowPage !== false) plugin.pages = plugin.pages.concat([windowPage])
  return plugin
}

// The most specific match wins, so plugins never need ordering:
// a running process beats a window title, which beats an app name.
function score(plugin, appId, title, processes) {
  if (plugin.appPattern && !plugin.appPattern.test(appId || "")) return -1
  if (plugin.titlePattern && !plugin.titlePattern.test(title || "")) return -1
  if (plugin.process && processes.indexOf(plugin.process) < 0) return -1
  return (plugin.process ? 4 : 0) + (plugin.titlePattern ? 2 : 0) + (plugin.appPattern ? 1 : 0)
}

function resolve(plugins, appId, title, processes) {
  let best = fallback
  let bestScore = -1
  for (const plugin of plugins) {
    const value = score(plugin, appId, title, processes)
    if (value > bestScore) {
      best = plugin
      bestScore = value
    }
  }
  return best
}

// Reads "hyprctl activewindow -j", a "---" line, then "ps -eo pid=,ppid=,comm=",
// and returns the names of everything running under the focused window.
function windowProcesses(output) {
  const split = output.indexOf("\n---\n")
  if (split < 0) return []

  let root = 0
  try {
    root = JSON.parse(output.slice(0, split)).pid
  } catch (e) {
    return []
  }

  const children = {}
  const names = {}
  for (const line of output.slice(split + 5).split("\n")) {
    const row = line.trim().match(/^(\d+)\s+(\d+)\s+(.+)$/)
    if (!row) continue
    names[row[1]] = row[3]
    if (!children[row[2]]) children[row[2]] = []
    children[row[2]].push(row[1])
  }

  const found = []
  const queue = [String(root)]
  while (queue.length) {
    const pid = queue.pop()
    if (names[pid]) found.push(names[pid])
    if (children[pid]) queue.push(...children[pid])
  }
  return found
}

// "ctrl+shift+t" -> ["wtype", "-M", "ctrl", "-M", "shift", "-k", "t", "-m", "shift", "-m", "ctrl"]
function wtypeArgs(chord) {
  const parts = chord.split("+")
  const key = parts.pop()
  const args = ["wtype"]
  for (const mod of parts) args.push("-M", mod)
  args.push("-k", key)
  for (const mod of parts.reverse()) args.push("-m", mod)
  return args
}

function command(action) {
  if (action.keys) return wtypeArgs(action.keys)
  if (action.hypr) return ["hyprctl", "dispatch", action.hypr]
  if (action.run) return action.run
  return null
}
