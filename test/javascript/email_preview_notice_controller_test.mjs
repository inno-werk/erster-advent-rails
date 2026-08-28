import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { runInNewContext } from "node:vm"

const source = readFileSync(new URL("../../app/javascript/controllers/email_preview_notice_controller.js", import.meta.url), "utf8")

function setup({ prompt = false, supported = true, id = "notice-id" } = {}) {
  const channels = []
  class Channel {
    constructor(name) { this.name = name; channels.push(this) }
    close() { this.closed = true }
  }
  const Controller = runInNewContext(source
    .replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
    .replace("export default class", "class NoticeController") + "\nNoticeController", { BroadcastChannel: supported ? Channel : undefined })
  const controller = new Controller()
  controller.idValue = id
  controller.element = { hidden: false }
  controller.hasPromptTarget = prompt
  controller.promptTarget = { hidden: false }
  controller.openedTarget = { hidden: true }
  controller.connect()
  return { controller, channels }
}

test("only a successful opening of this specific email dismisses its banner", () => {
  const { controller, channels } = setup()
  const channel = channels[0]
  channel.onmessage({ data: { type: "opened", id: "another-email" } })
  channel.onmessage({ data: { type: "failed", id: "notice-id" } })
  assert.equal(controller.element.hidden, false)
  channel.onmessage({ data: { type: "opened", id: "notice-id" } })
  assert.equal(controller.element.hidden, true)
  controller.disconnect()
  assert.equal(channel.closed, true)
})

test("the confirmation prompt switches to the opened message without hiding the whole page", () => {
  const { controller, channels } = setup({ prompt: true })
  channels[0].onmessage({ data: { type: "opened", id: "notice-id" } })
  assert.equal(controller.promptTarget.hidden, true)
  assert.equal(controller.openedTarget.hidden, false)
  assert.equal(controller.element.hidden, false)
})

test("unsupported browsers and pages with no preview identifier keep their notice", () => {
  for (const options of [{ supported: false }, { id: "" }]) {
    const { controller, channels } = setup(options)
    assert.equal(channels.length, 0)
    assert.equal(controller.element.hidden, false)
    controller.disconnect()
  }
})

test("the preview page announces its identifier without transmitting email contents", () => {
  const announcement = readFileSync(new URL("../../app/javascript/email_preview_opened.js", import.meta.url), "utf8")
  const messages = []
  let closed = false
  runInNewContext(announcement, {
    document: { body: { dataset: { emailPreviewNoticeId: "notice-id" } } },
    BroadcastChannel: class {
      constructor(name) { assert.equal(name, "account-email-preview") }
      postMessage(message) { messages.push(JSON.parse(JSON.stringify(message))) }
      close() { closed = true }
    }
  })
  assert.deepEqual(messages, [{ type: "opened", id: "notice-id" }])
  assert.equal(closed, true)
})
