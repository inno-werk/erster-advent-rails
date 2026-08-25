import { Controller } from "@hotwired/stimulus"

// Keeps a native colour swatch and a hex text field in sync, and mirrors the
// chosen colour onto a live preview.
export default class extends Controller {
  static targets = ["swatch", "hex", "preview", "form"]
  static values = { confirmTemplate: String }

  syncFromSwatch() {
    this.hexTarget.value = this.swatchTarget.value.toUpperCase()
    this.updatePreview()
  }

  syncFromHex() {
    const value = this.normalize(this.hexTarget.value)
    if (value) {
      this.swatchTarget.value = value
      this.updatePreview()
    }
  }

  // `--color-primary-dark` is substituted against :root, so an inherited
  // value would keep the saved colour. Set both explicitly on the preview.
  updatePreview() {
    const color = this.swatchTarget.value
    this.previewTargets.forEach((el) => {
      el.style.setProperty("--color-primary", color)
      el.style.setProperty(
        "--color-primary-dark",
        `color-mix(in srgb, ${color}, black 35%)`
      )
    })
    this.updateConfirmation(color)
  }

  // The confirmation names the colour being applied, so it has to track the
  // picker rather than the value the page was rendered with.
  updateConfirmation(color) {
    if (!this.hasFormTarget || !this.hasConfirmTemplateValue) return

    this.formTarget.setAttribute(
      "data-turbo-confirm",
      this.confirmTemplateValue.replace("%{color}", color.toUpperCase())
    )
  }

  normalize(value) {
    const hex = value.trim().replace(/^#/, "")
    if (!/^([0-9a-f]{3}|[0-9a-f]{6})$/i.test(hex)) return null
    const full = hex.length === 3 ? hex.split("").map((c) => c + c).join("") : hex
    return `#${full.toUpperCase()}`
  }
}
