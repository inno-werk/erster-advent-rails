import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: String }
  static targets = ["prompt", "opened"]

  connect() {
    if (!this.idValue || typeof BroadcastChannel === "undefined") return

    this.channel = new BroadcastChannel("account-email-preview")
    this.channel.onmessage = ({ data }) => {
      if (data?.type === "opened" && data.id === this.idValue) this.dismiss()
    }
  }

  dismiss() {
    if (this.hasPromptTarget) {
      this.promptTarget.hidden = true
      this.openedTarget.hidden = false
    } else {
      this.element.hidden = true
    }
  }

  disconnect() {
    this.channel?.close()
  }
}
