import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "instant", "hint"];
  static values = { current: String };

  connect() {
    if (this.hasCurrentValue) {
      this.inputTarget.value = this.#localValue(new Date(this.currentValue));
    }
    this.inputTarget.min = this.#localValue(new Date(Date.now() + 60_000));
    this.hintTarget.textContent = `Times use ${Intl.DateTimeFormat().resolvedOptions().timeZone}.`;
    this.update();
  }

  update() {
    this.inputTarget.setCustomValidity("");
    this.instantTarget.value = "";
    if (!this.inputTarget.value) return;

    const instant = new Date(this.inputTarget.value);
    if (Number.isNaN(instant.valueOf()) || this.#localValue(instant) !== this.inputTarget.value) {
      this.inputTarget.setCustomValidity("Choose a valid local date and time.");
      return;
    }

    this.instantTarget.value = instant.toISOString();
  }

  #localValue(instant) {
    const local = new Date(instant.valueOf() - instant.getTimezoneOffset() * 60_000);
    return local.toISOString().slice(0, 16);
  }
}
