import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["source", "frame"];
  static values = { url: String, frameId: String };

  async render(event) {
    event.preventDefault();
    const body = new FormData();
    body.append("preview[markdown]", this.sourceTarget.value);
    body.append("preview[frame_id]", this.frameIdValue);
    try {
      const headers = {
        Accept: "text/html",
        "Turbo-Frame": this.frameIdValue,
      };
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;
      if (csrfToken) headers["X-CSRF-Token"] = csrfToken;

      const response = await fetch(this.urlValue, {
        method: "POST",
        body,
        credentials: "same-origin",
        headers,
      });
      if (!response.ok) throw new Error("Preview request failed");
      this.frameTarget.outerHTML = await response.text();
    } catch (_error) {
      this.frameTarget.innerHTML = '<p role="status">Preview unavailable. Try again.</p>';
    }
  }
}
