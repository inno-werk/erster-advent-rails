import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="unsaved-changes"
//
// Watches a form for edits: the save buttons stay hidden until something
// actually changed, and leaving the page with unsaved changes asks first.
// Lives on the app shell (layouts/app) so the buttons can sit in the sticky
// bars outside the form element.
export default class extends Controller {
    static targets = ["form", "save", "status"];
    static values = {
        message: {
            type: String,
            default:
                "Sie haben ungespeicherte Änderungen. Möchten Sie die Seite wirklich verlassen?",
        },
    };

    connect() {
        this.dirty = false;
        if (!this.hasFormTarget) return;

        this.formTarget.addEventListener("submit", this.markSaved);
        document.addEventListener("turbo:submit-start", this.markSaved);
        document.addEventListener("turbo:before-visit", this.confirmLeaving);
        window.addEventListener("beforeunload", this.warnBeforeUnload);

        this.render();
    }

    disconnect() {
        if (this.hasFormTarget) {
            this.formTarget.removeEventListener("submit", this.markSaved);
        }
        document.removeEventListener("turbo:submit-start", this.markSaved);
        document.removeEventListener("turbo:before-visit", this.confirmLeaving);
        window.removeEventListener("beforeunload", this.warnBeforeUnload);
    }

    // Fired by input/change/trix-change bubbling out of the form
    markDirty() {
        if (this.dirty) return;

        this.dirty = true;
        this.render();
    }

    // Only our own form counts as "saved" — other submissions on the page
    // (e.g. deleting an image) must not clear the dirty state.
    markSaved = (event) => {
        const submitted =
            event?.detail?.formSubmission?.formElement ?? event?.target;
        if (this.hasFormTarget && submitted && submitted !== this.formTarget) return;

        this.dirty = false;
        this.render();
    };

    // Turbo navigation (links inside the app)
    confirmLeaving = (event) => {
        if (!this.dirty) return;
        if (window.confirm(this.messageValue)) return;

        event.preventDefault();
    };

    // Full page unload (reload, closing the tab, external links)
    warnBeforeUnload = (event) => {
        if (!this.dirty) return;

        event.preventDefault();
        // Legacy browsers still require a return value to show their dialog
        event.returnValue = this.messageValue;
    };

    render() {
        this.saveTargets.forEach((button) => {
            button.classList.toggle("hidden", !this.dirty);
        });
        this.statusTargets.forEach((status) => {
            status.textContent = this.dirty
                ? status.dataset.dirtyText || ""
                : status.dataset.cleanText || "";
        });
    }
}
