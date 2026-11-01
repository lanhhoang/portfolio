require "test_helper"
require "open3"
require "tmpdir"

class BrakemanTest < ActiveSupport::TestCase
  test "locked scanner runs even when a newer version is available" do
    output, error, status = scan("render plain: 'hello'")

    assert_predicate status, :success?, error
    assert_empty JSON.parse(output).fetch("warnings")
  end

  test "security warnings still fail the scan" do
    output, error, status = scan("eval(params[:code])")

    assert_equal 3, status.exitstatus, error
    assert_includes JSON.parse(output).fetch("warnings").map { |warning| warning.fetch("warning_type") }, "Dangerous Eval"
  end

  private

  def scan(action)
    Dir.mktmpdir("brakeman-test") do |directory|
      FileUtils.mkdir_p("#{directory}/app/controllers")
      FileUtils.mkdir_p("#{directory}/config")
      File.write("#{directory}/Gemfile", 'gem "rails", "8.1.4"')
      File.write("#{directory}/config/application.rb", "")
      File.write("#{directory}/app/controllers/examples_controller.rb", <<~RUBY)
        class ExamplesController < ActionController::Base
          protect_from_forgery with: :exception

          def show
            #{action}
          end
        end
      RUBY

      # Keep the version-check response deterministic and offline; run the real scanner.
      script = <<~RUBY
        require "brakeman"
        def Brakeman.ensure_latest(**)
          "A newer Brakeman version is available"
        end
        load ARGV.shift
      RUBY

      Open3.capture3(RbConfig.ruby, "-e", script, Rails.root.join("bin/brakeman").to_s,
        "--no-pager", "--quiet", "--format", "json", "--path", directory)
    end
  end
end
