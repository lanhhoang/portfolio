# frozen_string_literal: true

class SearchText
  def self.normalize(value)
    value.to_s.unicode_normalize(:nfc).downcase(:fold).unicode_normalize(:nfc)
  end
end
