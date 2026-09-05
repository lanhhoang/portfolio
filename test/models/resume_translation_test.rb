require "test_helper"

class ResumeTranslationTest < ActiveSupport::TestCase
  test "reports whether authored content is complete" do
    attributes = { title: "Résumé", description: "Current résumé" }

    assert ResumeTranslation.new(attributes).complete?
    attributes.each_key do |attribute|
      refute ResumeTranslation.new(attributes.merge(attribute => "")).complete?
    end
  end
end
