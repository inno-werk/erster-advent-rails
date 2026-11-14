import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { runInNewContext } from "node:vm"

const source = readFileSync(new URL("../../app/javascript/controllers/turnstile_controller.js", import.meta.url), "utf8")

function loadController(context) {
  return runInNewContext(source
    .replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
    .replace("export default class", "class TurnstileController") + "\nTurnstileController", context)
}

function environment() {
  const scripts = []
  const window = {}
  const document = {
    createElement: () => ({}),
    head: { appendChild(script) { scripts.push(script) } }
  }
  const context = { window, document, Promise, Error }
  return { context, window, scripts, Controller: loadController(context) }
}

function element(width = 400) {
  return { clientWidth: width, isConnected: true, cleared: 0, replaceChildren() { this.cleared += 1 } }
}

function connect(Controller, el) {
  const controller = new Controller()
  controller.element = el
  controller.siteKeyValue = "site-key"
  controller.connect()
  return controller
}

const flush = () => new Promise((resolve) => setImmediate(resolve))

test("loads the explicit-render script once and renders with the site key", async () => {
  const { window, scripts, Controller } = environment()
  const rendered = []
  const first = connect(Controller, element())
  const second = connect(Controller, element(250))
  assert.equal(scripts.length, 1)
  assert.match(scripts[0].src, /challenges\.cloudflare\.com\/turnstile\/v0\/api\.js\?render=explicit$/)

  window.turnstile = { render(el, options) { rendered.push(options); return `w${rendered.length}` }, remove() {} }
  scripts[0].onload()
  await flush()

  assert.equal(rendered.length, 2)
  assert.deepEqual({ ...rendered[0] }, { sitekey: "site-key", language: "de", size: "flexible" })
  assert.equal(rendered[1].size, "compact")
  assert.equal(first.element.cleared, 1)
  assert.equal(second.widgetId, "w2")
})

test("removes its widget on disconnect and skips rendering into detached elements", async () => {
  const { window, Controller } = environment()
  const removed = []
  let renders = 0
  window.turnstile = { render() { renders += 1; return "widget" }, remove(id) { removed.push(id) } }

  const controller = connect(Controller, element())
  await flush()
  controller.disconnect()
  assert.deepEqual(removed, ["widget"])
  assert.equal(controller.widgetId, null)

  const detached = element()
  detached.isConnected = false
  connect(Controller, detached)
  await flush()
  assert.equal(renders, 1)
})

test("a failed script load can be retried by a later connect", async () => {
  const { scripts, Controller } = environment()
  connect(Controller, element())
  scripts[0].onerror()
  await flush()
  connect(Controller, element())
  assert.equal(scripts.length, 2)
})
