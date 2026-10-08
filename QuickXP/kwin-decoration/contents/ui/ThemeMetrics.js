.pragma library

// Replaced by kdecoration.py for each theme. Kept so the template package loads.
const metrics = {
    "borderLeft": 0,
    "borderRight": 0,
    "borderTop": 0,
    "borderBottom": 0,
    "parts": {},
    "roles": {}
}

function part(id) {
    return metrics.parts[String(id)] || null
}

function roleId(name) {
    const value = metrics.roles[name]
    return typeof value === "number" ? value : 0
}
