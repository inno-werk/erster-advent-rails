import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="scroll-nav"
//
// Switches the navbar between its expanded hero state ("large") and the
// minimized purple bar ("small"). The switch happens the moment the bottom
// edge of the expanded logo touches the page content (marked with
// [data-nav-boundary]), in both scroll directions: the expanded logo is
// 200px tall against the minimized bar's ~93px, so returning to "large"
// any earlier on the way up would drop the logo onto the content.
export default class extends Controller {
    static DEFAULT_THRESHOLD = 10;

    connect() {
        this.lastScrollY = window.scrollY;
        this.ticking = false;
        this.threshold = this.computeThreshold();
        this.handleScroll = this.onScroll.bind(this);
        this.handleResize = this.onResize.bind(this);
        window.addEventListener("scroll", this.handleScroll, { passive: true });
        window.addEventListener("resize", this.handleResize, { passive: true });
        this.toggleBackground();
    }

    disconnect() {
        window.removeEventListener("scroll", this.handleScroll);
        window.removeEventListener("resize", this.handleResize);
    }

    computeThreshold() {
        const boundary = document.querySelector("[data-nav-boundary]");
        if (boundary) {
            // The marker's top edge is where the overlapping content starts;
            // data-nav-boundary="bottom" marks a hero band instead, whose
            // bottom edge is where the content starts.
            const rect = boundary.getBoundingClientRect();
            const edge = boundary.dataset.navBoundary === "bottom" ? rect.bottom : rect.top;
            const boundaryTop = edge + window.scrollY;
            const largeLogoBottom = this.measureCssHeight(
                "calc(var(--nav-top-offset, 0px) + var(--nav-logo-height, 0px))"
            );
            return Math.max(boundaryTop - largeLogoBottom, 0);
        }

        const hero = document.querySelector("[data-hero]");
        return hero ? hero.offsetHeight : this.constructor.DEFAULT_THRESHOLD;
    }

    // Resolves a CSS height expression (media queries, clamp()) to actual
    // pixels by measuring a probe element.
    measureCssHeight(expression) {
        const probe = document.createElement("div");
        probe.style.cssText =
            "position:absolute;visibility:hidden;pointer-events:none;" +
            `height:${expression};`;
        document.body.appendChild(probe);
        const height = probe.offsetHeight;
        probe.remove();
        return height;
    }

    onResize() {
        this.threshold = this.computeThreshold();
        this.toggleBackground();
    }

    onScroll() {
        if (this.ticking) return;

        this.ticking = true;
        requestAnimationFrame(() => {
            this.toggleBackground();
            this.ticking = false;
        });
    }

    toggleBackground() {
        const scrollY = window.scrollY;

        if (scrollY > this.threshold) {
            this.element.classList.remove("large");
            this.element.classList.add("small");

            if (scrollY > this.lastScrollY) {
                this.element.classList.remove("up");
                this.element.classList.add("down");
            } else {
                this.element.classList.remove("down");
                this.element.classList.add("up");
            }
        } else {
            this.element.classList.add("large");
            this.element.classList.remove("small", "down", "up");
        }

        this.lastScrollY = scrollY;
    }
}
