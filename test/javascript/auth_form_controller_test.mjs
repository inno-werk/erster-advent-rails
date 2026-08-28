import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { runInNewContext } from "node:vm"

const source = readFileSync(new URL("../../app/javascript/controllers/auth_form_controller.js", import.meta.url), "utf8")
const Controller = runInNewContext(source
  .replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
  .replace("export default class", "class AuthFormController") + "\nAuthFormController")

function form({ id = "registration-form", action = "/users", invalid = "false", password = "" } = {}) {
  const input = { value: password, type: "password" }
  let focused = false
  return {
    id, action, dataset: { authFormInvalid: invalid }, input,
    querySelector(selector) {
      if (selector === "[data-auth-password]") return input
      if (selector === '[aria-invalid="true"]' && invalid === "true") return { focus() { focused = true } }
      return null
    },
    focused: () => focused
  }
}

function setup(options) {
  const controller = new Controller()
  controller.element = form(options)
  controller.connect()
  return controller
}

function render(controller, nextForm) {
  controller.restorePassword({ detail: { newBody: {
    querySelector(selector) { return nextForm && selector === `#${nextForm.id}` ? nextForm : null }
  } } })
}

test("a failed form render restores the password masked and focuses the first invalid field", () => {
  const controller = setup({ password: "retained-password" })
  controller.rememberPassword()
  const next = form({ invalid: "true" })
  render(controller, next)
  assert.equal(next.input.value, "retained-password")
  assert.equal(next.input.type, "password")
  assert.equal(controller.pendingPassword, null)
  const connected = new Controller()
  connected.element = next
  connected.connect()
  assert.equal(next.focused(), true)
})

test("Turbo cache scrubbing does not lose the password needed by the imminent error render", () => {
  const controller = setup({ password: "retained-password" })
  controller.element.input.type = "text"
  controller.rememberPassword()
  controller.scrubInputs()
  assert.equal(controller.element.input.value, "")
  assert.equal(controller.element.input.type, "password")
  const next = form({ invalid: "true" })
  render(controller, next)
  assert.equal(next.input.value, "retained-password")
})

test("successful navigation, another form, and a different action never receive the password", () => {
  for (const next of [null, form(), form({ id: "admin-login-form", invalid: "true" }), form({ action: "/other", invalid: "true" })]) {
    const controller = setup({ password: "private-password" })
    controller.rememberPassword()
    render(controller, next)
    if (next) assert.equal(next.input.value, "")
    assert.equal(controller.pendingPassword, null)
  }
})

test("leaving the page or disconnecting removes pending and visible password values", () => {
  for (const method of ["leavePage", "disconnect"]) {
    const controller = setup({ password: "private-password" })
    controller.rememberPassword()
    controller[method]()
    assert.equal(controller.pendingPassword, null)
    assert.equal(controller.element.input.value, "")
  }
})

test("subsequent submissions keep the latest value and renders without submissions do not restore", () => {
  const controller = setup({ password: "old-password" })
  controller.rememberPassword()
  controller.element.input.value = "corrected-password"
  controller.rememberPassword()
  const next = form({ invalid: "true" })
  render(controller, next)
  assert.equal(next.input.value, "corrected-password")
  const unrelatedRender = form({ invalid: "true" })
  render(controller, unrelatedRender)
  assert.equal(unrelatedRender.input.value, "")
})

test("the visibility control supports auth forms without separate show and hide icons", () => {
  const visibilitySource = readFileSync(new URL("../../app/javascript/controllers/password_visibility_controller.js", import.meta.url), "utf8")
  const VisibilityController = runInNewContext(visibilitySource
    .replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
    .replace("export default class", "class VisibilityController") + "\nVisibilityController")
  const controller = new VisibilityController()
  controller.inputTarget = { type: "text", value: "retained-password" }
  controller.hasLabelTarget = true
  controller.labelTarget = { textContent: "Passwort verbergen" }
  controller.connect()
  assert.equal(controller.inputTarget.type, "password")
  assert.equal(controller.labelTarget.textContent, "Passwort anzeigen")
  controller.toggle()
  assert.equal(controller.inputTarget.type, "text")
  assert.equal(controller.labelTarget.textContent, "Passwort verbergen")
  controller.toggle()
  assert.equal(controller.inputTarget.type, "password")
  assert.equal(controller.inputTarget.value, "retained-password")
})
