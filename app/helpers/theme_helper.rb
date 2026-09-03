module ThemeHelper
  ACCENT_PRESETS = %w[brown green lime orange yellow].freeze

  def accent_preset(candidate = ENV["SITE_ACCENT"])
    candidate.to_s.presence_in(ACCENT_PRESETS) || "lime"
  end

  def theme_bootstrap_script
    javascript_tag nonce: true do
      <<~JAVASCRIPT.html_safe
        (() => {
          const theme = localStorage.getItem("portfolio-theme");
          if (theme === "light" || theme === "dark") {
            document.documentElement.dataset.theme = theme;
          }
        })();
      JAVASCRIPT
    end
  end
end
