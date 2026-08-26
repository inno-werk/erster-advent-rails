import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="gallery-slider"
//
// Moves the store detail gallery horizontally. Two inputs drive the same
// offset, so they compose seamlessly:
//   * vertical page scrolling - down moves the strip left, up moves it back
//   * click (or touch) and hold - dragging moves the strip under the cursor,
//     with a short flick momentum on release, like the XD prototype's
//     scroll group.
export default class extends Controller {
    static targets = ["track"];
    static SCROLL_FACTOR = 0.8;
    // Share of the release velocity kept per frame, and the speed below
    // which the flick is considered finished.
    static FRICTION = 0.94;
    static MIN_VELOCITY = 0.2;
    // Ceiling for the release velocity, so a single coarse pointer jump
    // (a laggy frame, a synthetic event) cannot fling the strip end to end.
    static MAX_VELOCITY = 60;
    // Pointer travel (px) before a press counts as a drag rather than a click.
    static DRAG_THRESHOLD = 3;

    connect() {
        this.offset = 0;
        this.lastScrollY = window.scrollY;
        this.ticking = false;
        this.measurementFrame = null;
        this.momentumFrame = null;
        this.maxOffset = 0;
        this.dragging = false;
        this.pointerId = null;
        this.velocity = 0;
        this.handleScroll = this.onScroll.bind(this);
        this.handleMeasure = this.queueMeasure.bind(this);
        this.handlePointerDown = this.onPointerDown.bind(this);
        this.handlePointerMove = this.onPointerMove.bind(this);
        this.handlePointerUp = this.onPointerUp.bind(this);
        this.handleDragStart = (event) => event.preventDefault();

        window.addEventListener("scroll", this.handleScroll, { passive: true });
        window.addEventListener("resize", this.handleMeasure, { passive: true });

        this.element.addEventListener("pointerdown", this.handlePointerDown);
        this.element.addEventListener("pointermove", this.handlePointerMove);
        this.element.addEventListener("pointerup", this.handlePointerUp);
        this.element.addEventListener("pointercancel", this.handlePointerUp);
        // Without this the browser starts its own image drag on mousedown.
        this.element.addEventListener("dragstart", this.handleDragStart);

        this.resizeObserver = new ResizeObserver(this.handleMeasure);
        this.resizeObserver.observe(this.element);
        this.resizeObserver.observe(this.trackTarget);

        this.imageLoadCleanups = Array.from(this.trackTarget.querySelectorAll("img")).map((image) => {
            if (image.complete) return null;

            image.addEventListener("load", this.handleMeasure, { once: true });
            return () => image.removeEventListener("load", this.handleMeasure);
        }).filter(Boolean);

        this.queueMeasure();
    }

    disconnect() {
        window.removeEventListener("scroll", this.handleScroll);
        window.removeEventListener("resize", this.handleMeasure);
        this.element.removeEventListener("pointerdown", this.handlePointerDown);
        this.element.removeEventListener("pointermove", this.handlePointerMove);
        this.element.removeEventListener("pointerup", this.handlePointerUp);
        this.element.removeEventListener("pointercancel", this.handlePointerUp);
        this.element.removeEventListener("dragstart", this.handleDragStart);
        this.resizeObserver?.disconnect();
        this.imageLoadCleanups?.forEach((cleanup) => cleanup());

        if (this.measurementFrame) {
            cancelAnimationFrame(this.measurementFrame);
        }

        this.stopMomentum();
    }

    queueMeasure() {
        if (this.measurementFrame) return;

        this.measurementFrame = requestAnimationFrame(() => {
            this.measurementFrame = null;
            this.measure();
        });
    }

    measure() {
        this.maxOffset = this.computeMaxOffset();
        this.offset = Math.min(this.offset, this.maxOffset);
        this.applyTransform();
    }

    onScroll() {
        if (this.ticking) return;

        this.ticking = true;
        requestAnimationFrame(() => {
            this.updateOffset();
            this.ticking = false;
        });
    }

    updateOffset() {
        const scrollY = window.scrollY;
        const delta = scrollY - this.lastScrollY;
        this.lastScrollY = scrollY;

        if (this.dragging || !this.isInMotionRange() || delta === 0) return;

        this.maxOffset = this.computeMaxOffset();

        this.offset = this.clamp(
            this.offset + delta * this.constructor.SCROLL_FACTOR,
            0,
            this.maxOffset
        );
        this.applyTransform();
    }

    onPointerDown(event) {
        // Left button only; touch and pen report button 0 as well.
        if (event.button !== 0) return;

        this.maxOffset = this.computeMaxOffset();
        if (this.maxOffset === 0) return;

        this.stopMomentum();

        this.dragging = true;
        this.pointerId = event.pointerId;
        this.pointerStartX = event.clientX;
        this.lastPointerX = event.clientX;
        this.lastPointerTime = event.timeStamp;
        this.velocity = 0;

        this.element.setPointerCapture(event.pointerId);
        this.element.classList.add("is-dragging");
    }

    onPointerMove(event) {
        if (!this.dragging || event.pointerId !== this.pointerId) return;

        const dx = event.clientX - this.lastPointerX;
        const elapsed = event.timeStamp - this.lastPointerTime;

        if (Math.abs(event.clientX - this.pointerStartX) > this.constructor.DRAG_THRESHOLD) {
            // The strip is being dragged, so keep the browser from turning
            // the gesture into a text selection.
            event.preventDefault();
        }

        if (elapsed > 0) {
            // px per frame at 60fps, which is the unit the momentum uses
            const velocity = (dx / elapsed) * (1000 / 60);
            const max = this.constructor.MAX_VELOCITY;
            this.velocity = this.clamp(velocity, -max, max);
        }

        this.offset = this.clamp(this.offset - dx, 0, this.maxOffset);
        this.lastPointerX = event.clientX;
        this.lastPointerTime = event.timeStamp;
        this.applyTransform();
    }

    onPointerUp(event) {
        if (!this.dragging || event.pointerId !== this.pointerId) return;

        this.dragging = false;
        this.pointerId = null;
        this.element.releasePointerCapture?.(event.pointerId);
        this.element.classList.remove("is-dragging");

        // A pointer that stopped moving before release should not fling.
        if (event.timeStamp - this.lastPointerTime > 100) {
            this.velocity = 0;
        }

        this.startMomentum();
    }

    startMomentum() {
        if (Math.abs(this.velocity) < this.constructor.MIN_VELOCITY) return;

        const step = () => {
            this.velocity *= this.constructor.FRICTION;

            const next = this.clamp(this.offset - this.velocity, 0, this.maxOffset);

            if (Math.abs(this.velocity) < this.constructor.MIN_VELOCITY || next === this.offset) {
                this.momentumFrame = null;
                return;
            }

            this.offset = next;
            this.applyTransform();
            this.momentumFrame = requestAnimationFrame(step);
        };

        this.momentumFrame = requestAnimationFrame(step);
    }

    stopMomentum() {
        if (this.momentumFrame) {
            cancelAnimationFrame(this.momentumFrame);
            this.momentumFrame = null;
        }

        this.velocity = 0;
    }

    applyTransform() {
        this.trackTarget.style.transform = `translate3d(${-this.offset}px, 0, 0)`;
    }

    computeMaxOffset() {
        const trackWidth = this.trackTarget.getBoundingClientRect().width;
        return Math.max(trackWidth - this.element.clientWidth, 0);
    }

    isInMotionRange() {
        const rect = this.element.getBoundingClientRect();
        return rect.bottom > 0 && rect.top < window.innerHeight;
    }

    clamp(value, min, max) {
        return Math.min(Math.max(value, min), max);
    }
}
