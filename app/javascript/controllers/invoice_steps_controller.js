import { Controller } from "@hotwired/stimulus"

// Invoice mailing page: a «Vorschau» button in the recipient list renders into
// the preview frame of step 2, so select that business, open the step and
// bring the frame into view.
export default class extends Controller {
  static targets = ["previewStep", "preview", "select"]

  showPreview(event) {
    if (this.hasSelectTarget) this.selectTarget.value = event.currentTarget.value
    this.previewStepTarget.open = true
    this.previewTarget.scrollIntoView({ behavior: "smooth", block: "start" })
  }
}
