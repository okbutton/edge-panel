.pragma library

// Turns Home Assistant entities into buttons. Each button carries the service it calls
// when tapped ("service": ["light", "toggle"]), or none if it only shows a value.

const icons = {
  light: "\u{F0335}",
  lightOff: "\u{F0336}",
  switch: "\u{F06A5}",
  input_boolean: "\u{F0521}",
  fan: "\u{F0210}",
  cover: "\u{F111B}",
  scene: "\u{F03D8}",
  script: "\u{F0BC1}",
  climate: "\u{F0393}",
  tv: "\u{F0502}",
  speaker: "\u{F04C3}",
  lock: "\u{F033E}",
  unlock: "\u{F033F}",
  button: "\u{F12A8}",
  thermometer: "\u{F050F}",
  person: "\u{F0004}",
  plus: "\u{F0415}",
  minus: "\u{F0374}"
}

// The domains a page made from an area includes.
const supported = ["light", "switch", "input_boolean", "fan", "cover", "scene", "script",
  "climate", "media_player", "lock", "button"]

function domainOf(entityId) {
  return entityId.split(".")[0]
}

function isSupported(entityId) {
  return supported.indexOf(domainOf(entityId)) >= 0
}

function temperature(value, unit) {
  return value === undefined || value === null ? "–" : `${value}${unit || "°"}`
}

// One entity can make several buttons: a thermostat gets − and + beside it.
function tilesFor(entityId, state) {
  const domain = domainOf(entityId)
  const attributes = state ? state.attributes || {} : {}
  const name = attributes.friendly_name || entityId
  const value = state ? state.state : "unknown"
  const base = { entity: entityId, label: name }

  if (!state || value === "unavailable") {
    return [Object.assign(base, { icon: icons[domain] || icons.button, detail: "Unavailable", status: "none" })]
  }

  const on = value === "on"
  switch (domain) {
  case "light": {
    const level = attributes.brightness ? Math.round(attributes.brightness / 2.55) + "%" : ""
    return [Object.assign(base, { icon: on ? icons.light : icons.lightOff, active: on,
      detail: on ? (level || "On") : "Off", service: ["light", "toggle"] })]
  }
  case "switch":
  case "input_boolean":
  case "fan":
    return [Object.assign(base, { icon: icons[domain], active: on, detail: on ? "On" : "Off",
      service: [domain, "toggle"] })]
  case "cover":
    return [Object.assign(base, { icon: icons.cover, active: value === "open",
      detail: value.charAt(0).toUpperCase() + value.slice(1), service: ["cover", "toggle"] })]
  case "scene":
    return [Object.assign(base, { icon: icons.scene, service: ["scene", "turn_on"] })]
  case "script":
    return [Object.assign(base, { icon: icons.script, active: on, detail: on ? "Running" : "",
      service: ["script", "turn_on"] })]
  case "button":
    return [Object.assign(base, { icon: icons.button, confirm: true, service: ["button", "press"] })]
  case "lock": {
    const locked = value === "locked"
    return [Object.assign(base, { icon: locked ? icons.lock : icons.unlock, active: !locked,
      detail: locked ? "Locked" : "Unlocked", confirm: true,
      service: ["lock", locked ? "unlock" : "lock"] })]
  }
  case "media_player": {
    const off = value === "off" || value === "standby"
    const playing = attributes.media_title || ""
    return [Object.assign(base, {
      icon: attributes.device_class === "speaker" ? icons.speaker : icons.tv,
      active: value === "playing",
      detail: off ? "Off" : playing || value.charAt(0).toUpperCase() + value.slice(1),
      service: off ? ["media_player", "turn_on"] : ["media_player", "media_play_pause"] })]
  }
  case "climate": {
    const unit = attributes.temperature_unit || "°"
    const target = attributes.temperature
    const step = attributes.target_temp_step || 0.5
    const tiles = [Object.assign(base, { icon: icons.climate, active: attributes.hvac_action === "heating",
      detail: `${temperature(attributes.current_temperature)} → ${temperature(target)}` })]
    if (typeof target === "number") {
      for (const [icon, change] of [[icons.minus, -step], [icons.plus, step]]) {
        tiles.push({ entity: entityId, icon, label: `${name} ${change < 0 ? "down" : "up"}`,
          detail: temperature(Math.round((target + change) * 10) / 10),
          service: ["climate", "set_temperature"], data: { temperature: target + change } })
      }
    }
    return tiles
  }
  default:
    return [Object.assign(base, { icon: icons.button, detail: value })]
  }
}

// Pages are [{ name, entities, sensors, people }]; long pages split so every button keeps its size.
function buildPages(pages, states, perPage) {
  const out = []
  for (const page of pages) {
    let tiles = roomTile(page.sensors, states)
    for (const entityId of page.people || []) tiles.push(personTile(entityId, states[entityId]))
    for (const entityId of page.entities || []) tiles = tiles.concat(tilesFor(entityId, states[entityId]))
    if (tiles.length === 0) continue
    const count = Math.ceil(tiles.length / perPage)
    for (let i = 0; i < count; i++) {
      out.push({ name: count > 1 ? `${page.name} ${i + 1}` : page.name,
        actions: tiles.slice(i * perPage, (i + 1) * perPage) })
    }
  }
  return out
}

// Buttons that restart or power off the machine behind a device (OctoPrint's host, a
// router) are a stray touch from trouble, so area pages leave them out.
const hiddenButtons = /^button\..*_(reboot|restart|shutdown)(_system|_octoprint)?$/

// One page per area, in Home Assistant's order, from its area, device and entity
// registries. Leaves out entities that are disabled, hidden, or settings and diagnostics
// (a camera's motion detection, a plug's reload button), as Home Assistant's own area
// cards do. An area's sensors are kept aside for its room temperature tile.
function areaPages(areas, devices, entities) {
  const deviceArea = {}
  for (const device of devices || []) deviceArea[device.id] = device.area_id
  const byArea = {}
  for (const entity of entities || []) {
    if (entity.disabled_by || entity.hidden_by || entity.entity_category) continue
    const sensor = domainOf(entity.entity_id) === "sensor"
    if (!sensor && !isSupported(entity.entity_id)) continue
    if (hiddenButtons.test(entity.entity_id)) continue
    const area = entity.area_id || deviceArea[entity.device_id]
    if (!area) continue
    if (!byArea[area]) byArea[area] = { entities: [], sensors: [] }
    if (sensor) byArea[area].sensors.push({ entity: entity.entity_id, device: entity.device_id })
    else byArea[area].entities.push(entity.entity_id)
  }
  return (areas || []).filter(area => byArea[area.area_id])
    .map(area => ({ name: area.name, entities: byArea[area.area_id].entities.sort(),
      sensors: byArea[area.area_id].sensors }))
}

function numeric(state) {
  return state && state.state !== "" && !isNaN(Number(state.state))
}

// The room's temperature and humidity, as one tile that only shows them. Uses sensors
// named "…_temperature" (so a 3D printer's bed and nozzle readings stay out), preferring
// a device that also measures humidity: a room sensor rather than a thermostat.
function roomTile(sensors, states) {
  const of = kind => (sensors || []).filter(sensor => {
    const state = states[sensor.entity]
    return numeric(state) && (state.attributes || {}).device_class === kind
  })
  const humidity = of("humidity")
  const temperatures = of("temperature").filter(sensor => /_temperature$/.test(sensor.entity))
  const paired = temperatures.find(t => humidity.some(h => h.device === t.device))
  const temperature = paired || temperatures[0]
  if (!temperature && !humidity.length) return []
  const humid = (temperature && humidity.find(h => h.device === temperature.device)) || humidity[0]
  const parts = []
  if (temperature) {
    const state = states[temperature.entity]
    parts.push(`${Math.round(Number(state.state) * 10) / 10}${(state.attributes || {}).unit_of_measurement || "°"}`)
  }
  if (humid) parts.push(`${Math.round(Number(states[humid.entity].state))}%`)
  return [{ entity: (temperature || humid).entity, icon: icons.thermometer, label: "Room",
    detail: parts.join(" · ") }]
}

// Who is in which room, from Bermuda's area sensors ("Bruce's iPhone Area"). Null when
// Bermuda isn't installed.
function peoplePage(entities) {
  const people = (entities || []).filter(entity => entity.platform === "bermuda" &&
    !entity.disabled_by && /_area$/.test(entity.entity_id)).map(entity => entity.entity_id).sort()
  return people.length ? { name: "People", people } : null
}

function personTile(entityId, state) {
  const name = ((state && state.attributes.friendly_name) || entityId)
    .replace(/ Area$/, "").replace(/['’]s (iPhone|Phone|Pixel|Galaxy|Watch)$/i, "")
  const value = state ? state.state : "unknown"
  const away = value === "unknown" || value === "unavailable" || value === "not_home"
  return { entity: entityId, icon: icons.person, label: name, active: !away,
    detail: away ? "Not seen" : value }
}

const sourceKinds = {
  grid: { name: "Electricity", colour: "#4e96d6" },
  gas: { name: "Gas", colour: "#d9822b" },
  solar: { name: "Solar", colour: "#e8c547" },
  water: { name: "Water", colour: "#3fb6b6" }
}

// The energy dashboard's sources, from "energy/get_prefs": what each one measures,
// what it costs, and (for the grid) its live power. Handles both the old grid format
// (flow_from lists) and the new one.
function energySources(prefs) {
  const sources = []
  for (const source of (prefs && prefs.energy_sources) || []) {
    const kind = sourceKinds[source.type]
    if (!kind) continue
    const flows = source.flow_from || [source]
    for (const flow of flows) {
      if (!flow.stat_energy_from) continue
      sources.push({ type: source.type, name: kind.name, colour: kind.colour,
        energy: flow.stat_energy_from, cost: flow.stat_cost || null,
        rate: source.stat_rate || null })
    }
  }
  return sources
}

// Today's statistics: hourly use for the chart, and the day's total for each one.
function statisticsCommands(sources, midnight) {
  const energyIds = sources.map(source => source.energy)
  const commands = [{ type: "recorder/statistics_during_period", start_time: midnight,
    period: "hour", statistic_ids: energyIds, types: ["change"], units: { energy: "kWh" } }]
  for (const source of sources) {
    commands.push({ type: "recorder/statistic_during_period", statistic_id: source.energy,
      calendar: { period: "day" }, types: ["change"], units: { energy: "kWh" } })
    if (source.cost) commands.push({ type: "recorder/statistic_during_period",
      statistic_id: source.cost, calendar: { period: "day" }, types: ["change"] })
  }
  return commands
}

// Reads the replies to statisticsCommands into the sources, adding hourly (24 numbers),
// today and todayCost.
function readStatistics(sources, results) {
  const hourly = results[0] || {}
  let next = 1
  return sources.map(source => {
    const hours = []
    for (let hour = 0; hour < 24; hour++) hours.push(0)
    for (const row of hourly[source.energy] || []) {
      const hour = new Date(row.start).getHours()
      hours[hour] += Math.max(0, row.change || 0)
    }
    const today = results[next++]
    const cost = source.cost ? results[next++] : null
    return Object.assign({}, source, { hourly: hours,
      today: today ? today.change || 0 : null,
      todayCost: cost ? cost.change || 0 : null })
  })
}

const currencies = { GBP: "£", EUR: "€", USD: "$" }

function money(value, unit) {
  if (value === null || value === undefined) return ""
  const symbol = currencies[unit] || ""
  return symbol ? `${symbol}${value.toFixed(2)}` : `${value.toFixed(2)} ${unit || ""}`.trim()
}

function power(watts) {
  if (isNaN(watts)) return "–"
  return Math.abs(watts) >= 1000 ? `${(watts / 1000).toFixed(2)} kW` : `${Math.round(watts)} W`
}
