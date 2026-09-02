import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { runInNewContext } from "node:vm"

// Exercise the controller's threshold logic without a browser or Stimulus.
const source = readFileSync(new URL("../../app/javascript/controllers/scroll_nav_controller.js", import.meta.url), "utf8")

function build() {
  const sandbox = { window: { scrollY: 0 }, document: {} }
  const Controller = runInNewContext(source
    .replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
    .replace("export default class", "class ScrollNavController") + "\nScrollNavController", sandbox)
  return { Controller, sandbox }
}

// The 1920px geometry: content starts 720px down, the expanded logo reaches
// 200px, the minimized bar 93px.
function withBoundary({ boundaryTop = 720, navBoundary } = {}) {
  const { Controller, sandbox } = build()
  sandbox.document.querySelector = (selector) =>
    selector === "[data-nav-boundary]"
      ? { dataset: navBoundary ? { navBoundary } : {}, getBoundingClientRect: () => ({ top: boundaryTop, bottom: boundaryTop }) }
      : null
  const controller = new Controller()
  controller.measureCssHeight = (expression) => (expression.includes("nav-small-height") ? 93 : 200)
  return controller
}

function scrolling(threshold) {
  const { Controller, sandbox } = build()
  const controller = new Controller()
  const classes = new Set(["large"])
  controller.element = {
    classList: {
      add: (...names) => names.forEach((name) => classes.add(name)),
      remove: (...names) => names.forEach((name) => classes.delete(name)),
    },
  }
  controller.threshold = threshold
  controller.lastScrollY = 0
  return {
    classes,
    scrollTo(y) {
      sandbox.window.scrollY = y
      controller.toggleBackground()
    },
  }
}

test("the switch happens where the expanded logo would touch the content", () => {
  assert.equal(withBoundary().computeThreshold(), 720 - 200)
})

test("a hero band boundary measures from its bottom edge", () => {
  assert.equal(withBoundary({ boundaryTop: 900, navBoundary: "bottom" }).computeThreshold(), 900 - 200)
})

test("scrolling up keeps the navbar minimized until the content clears the expanded logo", () => {
  const { classes, scrollTo } = scrolling(520)

  scrollTo(700)
  assert.ok(classes.has("small") && classes.has("down"))

  // 560 leaves only 160px above the content - not enough for the 200px logo,
  // so the bar must stay minimized and merely slide back into view.
  scrollTo(560)
  assert.ok(classes.has("small"), "navbar expanded while the logo would overlap the content")
  assert.ok(classes.has("up") && !classes.has("down"))

  scrollTo(519)
  assert.ok(classes.has("large") && !classes.has("small"))
})
