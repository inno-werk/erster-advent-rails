import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { runInNewContext } from "node:vm"

// Exercise the controller's event logic without a browser or Stimulus target binding.
const source = readFileSync(new URL("../../app/javascript/controllers/admin_list_controller.js", import.meta.url), "utf8")
const Controller = runInNewContext(source
  .replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
  .replace("export default class", "class AdminListController") + "\nAdminListController")

function setup(value) {
  const controller = new Controller()
  let submissions = 0
  controller.searchTarget = { value, form: { requestSubmit() { submissions++ } } }
  controller.connect()
  return { controller, submissions: () => submissions }
}

test("clearing a populated search submits once across input and search events", () => {
  const { controller, submissions } = setup("Bern")
  controller.searchTarget.value = ""
  controller.searchChanged()
  controller.searchChanged()
  assert.equal(submissions(), 1)
})

test("ordinary typing and an initially empty input do not submit", () => {
  const { controller, submissions } = setup("")
  controller.searchChanged()
  controller.searchTarget.value = "B"
  controller.searchChanged()
  controller.searchTarget.value = "Bern"
  controller.searchChanged()
  assert.equal(submissions(), 0)
})

test("deleting the last character or clearing a later query submits again", () => {
  const { controller, submissions } = setup("B")
  controller.searchTarget.value = " "
  controller.searchChanged()
  controller.searchTarget.value = "Zürich"
  controller.searchChanged()
  controller.searchTarget.value = ""
  controller.searchChanged()
  assert.equal(submissions(), 2)
})
