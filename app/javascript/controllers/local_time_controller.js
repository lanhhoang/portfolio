import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const instant = new Date(this.element.dateTime);
    if (Number.isNaN(instant.valueOf())) return;

    this.element.textContent = instant.toLocaleString(undefined, {
      year: "numeric", month: "short", day: "numeric",
      hour: "2-digit", minute: "2-digit", timeZoneName: "short",
    });
  }
}
