require "test_helper"

class Admin::SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "admin authentication responses send CSP and standard security headers" do
    get new_admin_session_path

    assert_response :success
    assert_includes response.headers.fetch("Content-Security-Policy"), "default-src 'self'"
    assert_includes response.headers.fetch("Content-Security-Policy"), "frame-ancestors 'none'"
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"]
    assert_equal "camera=(), microphone=(), geolocation=()", response.headers["Permissions-Policy"]
  end

  test "parameter filtering removes nested authentication secrets" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(
      totp: { code: "123456" },
      recovery: { code: "AAAA-BBBB-CCCC-DDDD-EEEE" },
      token: "signed-reset-token",
      password: "secret-password"
    )

    assert_equal "[FILTERED]", filtered[:totp]
    assert_equal "[FILTERED]", filtered[:recovery]
    assert_equal "[FILTERED]", filtered[:token]
    assert_equal "[FILTERED]", filtered[:password]
  end
end
