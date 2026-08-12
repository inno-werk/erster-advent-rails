import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="multiselect"
export default class extends Controller {
    static targets = ["checkbox", "count", "noun", "tags"];

    update() {
        const selected = this.checkboxTargets.filter((cb) => cb.checked);

        this.countTarget.textContent = selected.length;
        if (this.hasNounTarget) {
            this.nounTarget.textContent =
                selected.length === 1 ? "Kategorie" : "Kategorien";
        }
        this.tagsTarget.innerHTML = selected
            .map((cb) => this.tagMarkup(cb.value))
            .join("");
    }

    // Unchecks the box behind a chip's "x" button
    remove(event) {
        const value = event.currentTarget.dataset.value;
        const checkbox = this.checkboxTargets.find((cb) => cb.value === value);
        if (!checkbox) return;

        checkbox.checked = false;
        // Let the change bubble: it redraws the chips and marks the form dirty
        checkbox.dispatchEvent(new Event("change", { bubbles: true }));
    }

    tagMarkup(value) {
        const label = value.replace(/[&<>"]/g, (char) => `&#${char.charCodeAt(0)};`);

        return `
          <span class="field-chip">
            ${label}
            <button type="button" data-action="multiselect#remove" data-value="${label}"
                    aria-label="${label} entfernen">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"
                   stroke-width="2" stroke="currentColor" class="h-3.5 w-3.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
              </svg>
            </button>
          </span>`;
    }
}
