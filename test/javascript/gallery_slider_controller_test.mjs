import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { runInNewContext } from "node:vm"

// Exercise the loading state without a browser or Stimulus.
const source = readFileSync(new URL("../../app/javascript/controllers/gallery_slider_controller.js", import.meta.url), "utf8")

function fakeImage(complete) {
  const listeners = {}
  return {
    complete,
    addEventListener: (type, fn) => { listeners[type] = fn },
    removeEventListener: (type) => { delete listeners[type] },
    fire: (type) => listeners[type]?.(),
  }
}

function connect(images) {
  const timers = []
  const sandbox = {
    window: { scrollY: 0, innerHeight: 800, addEventListener() {}, removeEventListener() {} },
    requestAnimationFrame: () => 1,
    cancelAnimationFrame() {},
    setTimeout: (fn) => { timers.push(fn); return timers.length },
    clearTimeout() {},
    ResizeObserver: class { observe() {} disconnect() {} },
  }
  const Controller = runInNewContext(source
    .replace('import { Controller } from "@hotwired/stimulus";', "class Controller {}")
    .replace("export default class", "class GallerySliderController") + "\nGallerySliderController", sandbox)

  const classes = new Set()
  const controller = new Controller()
  controller.element = {
    classList: { add: (name) => classes.add(name), remove: (name) => classes.delete(name) },
    addEventListener() {},
    removeEventListener() {},
  }
  controller.trackTarget = { querySelectorAll: () => images }
  controller.connect()
  return { classes, timers }
}

test("the strip stays hidden until every image has loaded or failed", () => {
  const images = [fakeImage(false), fakeImage(false), fakeImage(true)]
  const { classes } = connect(images)

  assert.ok(classes.has("is-loading"))
  images[0].fire("load")
  assert.ok(classes.has("is-loading"))
  images[1].fire("error")
  assert.ok(!classes.has("is-loading"))
})

test("already loaded images show the strip immediately", () => {
  const { classes, timers } = connect([fakeImage(true), fakeImage(true)])

  assert.ok(!classes.has("is-loading"))
  assert.equal(timers.length, 0)
})

test("slow images cannot keep the strip hidden past the timeout", () => {
  const { classes, timers } = connect([fakeImage(false)])

  assert.ok(classes.has("is-loading"))
  timers[0]()
  assert.ok(!classes.has("is-loading"))
})
