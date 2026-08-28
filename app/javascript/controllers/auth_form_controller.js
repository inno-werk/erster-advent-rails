import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.pendingPassword = null
    this.element.querySelector('[aria-invalid="true"]')?.focus()
  }

  rememberPassword() {
    this.pendingPassword = this.passwordInput?.value ?? null
  }

  restorePassword(event) {
    const password = this.pendingPassword
    this.pendingPassword = null
    if (password === null) return

    const form = event.detail.newBody.querySelector(`#${this.element.id}`)
    if (!form || form.action !== this.element.action || form.dataset.authFormInvalid !== "true") return

    const input = form.querySelector('[data-auth-password]')
    if (input) {
      // Only a DOM property: never serialize the password into HTML or storage.
      input.type = "password"
      input.value = password
    }
  }

  scrubInputs() {
    if (this.passwordInput) {
      this.passwordInput.type = "password"
      this.passwordInput.value = ""
    }
  }

  leavePage() {
    this.pendingPassword = null
    this.scrubInputs()
  }

  disconnect() {
    this.leavePage()
  }

  get passwordInput() {
    return this.element.querySelector('[data-auth-password]')
  }
}
