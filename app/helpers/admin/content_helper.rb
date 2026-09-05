module Admin::ContentHelper
  LOCALE_NAMES = { "en" => "English", "fr" => "French", "vi" => "Vietnamese" }.freeze

  def translation_state_label(translation)
    translation.respond_to?(:state) ? translation.state.humanize : nil
  end

  def markdown_preview_frame_id(translation)
    owner = translation.model_name.element.delete_suffix("_translation")
    "#{owner}_#{translation.locale}_markdown_preview"
  end
end
