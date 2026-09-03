import { Controller } from "@hotwired/stimulus";

const STORAGE_KEY = "portfolio-theme";
const THEMES = ["light", "dark"];

export default class extends Controller {
  static targets = ["toggle"];
  static values = {
    lightLabel: String,
    darkLabel: String,
  };

  connect() {
    this.systemTheme = window.matchMedia("(prefers-color-scheme: dark)");
    this.handleSystemChange = () => {
      if (!this.savedTheme) this.sync();
    };
    this.systemTheme.addEventListener("change", this.handleSystemChange);
    this.sync();
  }

  disconnect() {
    this.systemTheme.removeEventListener("change", this.handleSystemChange);
  }

  toggle() {
    const nextTheme = this.currentTheme === "dark" ? "light" : "dark";
    localStorage.setItem(STORAGE_KEY, nextTheme);
    document.documentElement.dataset.theme = nextTheme;
    this.sync();
  }

  get savedTheme() {
    const value = localStorage.getItem(STORAGE_KEY);
    return THEMES.includes(value) ? value : null;
  }

  get currentTheme() {
    return this.savedTheme || (this.systemTheme.matches ? "dark" : "light");
  }

  sync() {
    const dark = this.currentTheme === "dark";
    this.toggleTarget.setAttribute("aria-pressed", dark.toString());
    this.toggleTarget.setAttribute(
      "aria-label",
      dark ? this.lightLabelValue : this.darkLabelValue,
    );
    this.toggleTarget.textContent = dark
      ? this.lightLabelValue
      : this.darkLabelValue;
  }
}
