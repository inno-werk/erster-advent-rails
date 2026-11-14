import { Controller } from "@hotwired/stimulus"

const SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
let scriptPromise = null

// Loads the Cloudflare script once per page lifetime; explicit rendering keeps
// the widget working across Turbo visits and 422 re-renders.
function loadTurnstile() {
  if (window.turnstile) return Promise.resolve(window.turnstile)
  if (scriptPromise) return scriptPromise

  scriptPromise = new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = SCRIPT_URL
    script.async = true
    script.defer = true
    script.onload = () => resolve(window.turnstile)
    script.onerror = () => {
      scriptPromise = null
      reject(new Error("Turnstile could not be loaded"))
    }
    document.head.appendChild(script)
  })
  return scriptPromise
}

export default class extends Controller {
  static values = { siteKey: String }

  connect() {
    this.element.replaceChildren()
    this.widgetId = null
    loadTurnstile().then((turnstile) => {
      if (!turnstile || !this.element.isConnected || this.widgetId !== null) return

      this.widgetId = turnstile.render(this.element, {
        sitekey: this.siteKeyValue,
        language: "de",
        size: this.element.clientWidth < 300 ? "compact" : "flexible"
      })
    }).catch(() => {
      // The server rejects the submission with a visible message if no token is sent.
    })
  }

  disconnect() {
    if (this.widgetId !== null) window.turnstile?.remove(this.widgetId)
    this.widgetId = null
  }
}
