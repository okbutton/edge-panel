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

// Pages are [{ name, entities }]; long pages split so every button keeps its size.
function buildPages(pages, states, perPage) {
  const out = []
  for (const page of pages) {
    let tiles = []
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

// Asks Home Assistant for each area and its entities, as JSON.
const areaTemplate = '{% set ns = namespace(pages=[]) %}{% for area in areas() %}' +
  '{% set ns.pages = ns.pages + [{"name": area_name(area), "entities": area_entities(area)}] %}' +
  '{% endfor %}{{ ns.pages | tojson }}'
