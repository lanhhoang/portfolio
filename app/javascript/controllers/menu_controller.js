import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "label", "panel"];
  static values = {
    openLabel: String,
    closeLabel: String,
  };

  connect() {
    this.close();
    this.element.dataset.menuConnected = "";
    this.handleKeydown = this.handleKeydown.bind(this);
    document.addEventListener("keydown", this.handleKeydown);
  }

  disconnect() {
    delete this.element.dataset.menuConnected;
    document.removeEventListener("keydown", this.handleKeydown);
  }

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close();
  }

  open() {
    this.panelTarget.hidden = false;
    this.buttonTarget.setAttribute("aria-expanded", "true");
    this.labelTarget.textContent = this.closeLabelValue;
  }

  close() {
    this.panelTarget.hidden = true;
    this.buttonTarget.setAttribute("aria-expanded", "false");
    this.labelTarget.textContent = this.openLabelValue;
  }

  handleKeydown(event) {
    if (event.key === "Escape" && !this.panelTarget.hidden) {
      this.close();
      this.buttonTarget.focus();
    }
  }
}
