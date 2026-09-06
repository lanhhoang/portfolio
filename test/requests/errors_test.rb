# frozen_string_literal: true

require "test_helper"

class ErrorsTest < ActionDispatch::IntegrationTest
  test "an unknown French URL receives a branded French 404" do
    # consider_all_requests_local makes DebugExceptions render its debug page
    # before ShowExceptions can reach the exceptions app; production never sets it.
    original_detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false

    get "/fr/this-page-does-not-exist"

    assert_response :not_found
    assert_includes response.body, "Page introuvable"
    assert_includes response.body, "Retour à l’accueil"
    assert_includes response.body, 'name="robots" content="noindex,nofollow"'
    assert_not_includes response.body, "ActionController::RoutingError"
  ensure
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = original_detailed
  end

  test "direct 422 honors a supported browser locale and quality values" do
    get "/422", headers: { "Accept-Language" => "fr;q=0,vi-VN;q=0.9,en;q=0.5" }

    assert_response :unprocessable_entity
    assert_includes response.body, "Không thể xử lý yêu cầu"
    assert_includes response.body, 'lang="vi"'
  end

  test "500 never renders exception details" do
    get "/500", headers: { "Accept-Language" => "en" }

    assert_response :internal_server_error
    assert_includes response.body, "Something went wrong"
    assert_not_includes response.body, "RuntimeError"
    assert_not_includes response.body, "backtrace"
  end
end
