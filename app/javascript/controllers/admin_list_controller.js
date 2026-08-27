import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "search"]

  connect() {
    this.lastSearchValue = this.searchTarget.value.trim()
  }

  searchChanged() {
    const value = this.searchTarget.value.trim()
    const cleared = this.lastSearchValue !== "" && value === ""
    this.lastSearchValue = value
    if (cleared) this.searchTarget.form.requestSubmit()
  }

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  closeBackdrop(event) {
    if (event.target !== this.dialogTarget) return
    const { left, right, top, bottom } = this.dialogTarget.getBoundingClientRect()
    if (event.clientX < left || event.clientX > right || event.clientY < top || event.clientY > bottom) this.close()
  }
}
