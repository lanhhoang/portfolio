# frozen_string_literal: true

require "test_helper"
require "yaml"

class RecurringScheduleTest < ActiveSupport::TestCase
  test "production scans for due translations every minute" do
    config = YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    task = config.fetch("production").fetch("publish_due_translations")

    assert_equal "PublishDueTranslationsJob", task.fetch("class")
    assert_equal "every minute", task.fetch("schedule")
  end
end
