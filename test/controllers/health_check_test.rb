require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "GET /up reports a booted application" do
    get "/up"

    assert_response :success
    assert_equal "text/html", response.media_type
  end
end
