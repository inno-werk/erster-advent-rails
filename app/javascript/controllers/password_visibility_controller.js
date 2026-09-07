import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "showIcon", "hideIcon", "label"]

  connect() {
    this.visible = false
    this.updateVisibility()
  }

  toggle(event) {
    event?.preventDefault()
    this.visible = !this.visible
    this.updateVisibility()
  }

  updateVisibility() {
    this.inputTarget.type = this.visible ? "text" : "password"
    if (this.hasShowIconTarget) this.showIconTarget.classList.toggle("hidden", this.visible)
    if (this.hasHideIconTarget) this.hideIconTarget.classList.toggle("hidden", !this.visible)

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.visible ? "Passwort verbergen" : "Passwort anzeigen"
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-pressed", this.visible.toString())
    }
  }
}
