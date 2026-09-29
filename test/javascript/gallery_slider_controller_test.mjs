import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { runInNewContext } from "node:vm"

// Exercise the loading state and the touch/pointer modes without a browser
// or Stimulus.
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

function listenerTarget() {
  const listeners = new Map()
  return {
    listeners,
    addEventListener: (type, handler) => listeners.set(type, handler),
    removeEventListener: (type, handler) => {
      if (listeners.get(type) === handler) listeners.delete(type)
    },
  }
}

function connect(images = [], { coarse = false, scrollY = 0, rect = { top: 100, bottom: 400 }, trackWidth = 2000 } = {}) {
  const timers = []
  const frames = []
  const media = { ...listenerTarget(), matches: coarse }
  const window = { ...listenerTarget(), scrollY, innerHeight: 800, matchMedia: () => media }
  const sandbox = {
    window,
    document: { documentElement: { clientHeight: 800 } },
    requestAnimationFrame: (callback) => frames.push(callback),
    cancelAnimationFrame() {},
    setTimeout: (fn) => { timers.push(fn); return timers.length },
    clearTimeout() {},
    ResizeObserver: class { observe() {} disconnect() {} },
  }
  const Controller = runInNewContext(source
    .replace('import { Controller } from "@hotwired/stimulus";', "class Controller {}")
    .replace("export default class", "class GallerySliderController") + "\nGallerySliderController", sandbox)

  const classes = new Set()
  const element = {
    ...listenerTarget(),
    clientWidth: 400,
    classList: { add: (name) => classes.add(name), remove: (name) => classes.delete(name) },
    setPointerCapture() {},
    hasPointerCapture: () => true,
    releasePointerCapture() {},
    getBoundingClientRect: () => rect,
    style: {
      props: {},
      setProperty(name, value) { this.props[name] = value },
      removeProperty(name) { delete this.props[name] },
    },
  }
  const track = {
    style: { transform: "translate3d(-120px, 0, 0)" },
    querySelectorAll: () => images,
    getBoundingClientRect: () => ({ width: trackWidth }),
  }

  const controller = new Controller()
  controller.element = element
  controller.trackTarget = track
  controller.connect()
  return { controller, classes, timers, frames, media, window, element, track }
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

test("touch screens leave the strip to native scrolling", () => {
  const { window, element, track } = connect([], { coarse: true })

  assert.equal(window.listeners.has("scroll"), false)
  assert.equal(element.listeners.has("pointerdown"), false)
  assert.equal(track.style.transform, "translate3d(-120px, 0, 0)")
})

test("touch screens still show the spinner while images load", () => {
  const images = [fakeImage(false)]
  const { classes, track } = connect(images, { coarse: true })

  assert.ok(classes.has("is-loading"))
  images[0].fire("load")
  assert.ok(!classes.has("is-loading"))
  assert.equal(track.style.transform, "translate3d(-120px, 0, 0)")
})

test("touch screens drift the strip over the page scroll that shows the gallery", () => {
  // 300px tall gallery 100px below the top: on screen from scroll 0 to 400.
  const { element, frames } = connect([], { coarse: true })
  frames.shift()()

  assert.deepEqual({ ...element.style.props }, {
    "--gallery-drift-start": "0px",
    "--gallery-drift-end": "400px",
    "--gallery-drift": "320px",
  })
})

test("the drift starts once a lower gallery enters the screen", () => {
  // Gallery 1100px down the page (scrolled 500, 600 from the top of the screen).
  const { element, frames } = connect([], { coarse: true, scrollY: 500, rect: { top: 600, bottom: 900 } })
  frames.shift()()

  assert.equal(element.style.props["--gallery-drift-start"], "300px")
  assert.equal(element.style.props["--gallery-drift-end"], "1400px")
})

test("the drift never runs past the last image", () => {
  const { element, frames } = connect([], { coarse: true, trackWidth: 600 })
  frames.shift()()

  assert.equal(element.style.props["--gallery-drift"], "200px")
})

test("switching to a fine pointer removes the drift", () => {
  const { element, frames, media, window } = connect([], { coarse: true })
  frames.shift()()

  media.matches = false
  media.listeners.get("change")()

  assert.deepEqual({ ...element.style.props }, {})
  assert.equal(window.listeners.has("scroll"), true)
})

test("fine pointers drive the strip from page scroll and dragging", () => {
  const { window, element } = connect()

  assert.equal(window.listeners.has("scroll"), true)
  assert.equal(element.listeners.has("pointerdown"), true)
})

test("switching to a touch screen hands the strip back at its start", () => {
  const { controller, media, window, element, track } = connect()
  controller.offset = 300

  media.matches = true
  media.listeners.get("change")()

  assert.equal(window.listeners.has("scroll"), false)
  assert.equal(element.listeners.has("pointerdown"), false)
  assert.equal(controller.offset, 0)
  assert.equal(track.style.transform, "")
})

test("a cancelled drag stops instead of flinging the strip", () => {
  const { controller, element, frames, classes } = connect()
  frames.length = 0

  element.listeners.get("pointerdown")({ button: 0, pointerId: 1, clientX: 200, timeStamp: 0 })
  element.listeners.get("pointermove")({ pointerId: 1, clientX: 170, timeStamp: 16, preventDefault() {} })
  element.listeners.get("pointercancel")({ pointerId: 1, timeStamp: 20 })

  assert.equal(controller.dragging, false)
  assert.equal(controller.velocity, 0)
  assert.equal(classes.has("is-dragging"), false)
  assert.equal(frames.length, 0)
})

test("a released flick keeps its momentum", () => {
  const { controller, element, frames } = connect()
  frames.length = 0

  element.listeners.get("pointerdown")({ button: 0, pointerId: 1, clientX: 200, timeStamp: 0 })
  element.listeners.get("pointermove")({ pointerId: 1, clientX: 170, timeStamp: 16, preventDefault() {} })
  element.listeners.get("pointerup")({ pointerId: 1, timeStamp: 20 })

  assert.notEqual(controller.velocity, 0)
  assert.equal(frames.length, 1)
})
