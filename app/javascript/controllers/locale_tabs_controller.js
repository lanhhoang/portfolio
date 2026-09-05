import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "panel"];

  connect() {
    this.select(
      this.tabTargets.findIndex(
        (tab) => tab.getAttribute("aria-selected") === "true",
      ),
    );
  }

  choose(event) {
    this.select(this.tabTargets.indexOf(event.currentTarget));
  }

  move(event) {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
    event.preventDefault();
    const current = this.tabTargets.indexOf(event.currentTarget);
    const index =
      event.key === "Home"
        ? 0
        : event.key === "End"
          ? this.tabTargets.length - 1
          : (current +
              (event.key === "ArrowRight" ? 1 : -1) +
              this.tabTargets.length) %
            this.tabTargets.length;
    this.select(index);
    this.tabTargets[index].focus();
  }

  select(index) {
    this.tabTargets.forEach((tab, position) => {
      const selected = position === index;
      tab.setAttribute("aria-selected", selected.toString());
      tab.tabIndex = selected ? 0 : -1;
      this.panelTargets[position].hidden = !selected;
    });
  }
}
