# frozen_string_literal: true

require "application_system_test_case"

class ContactFlowTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  test "visitor submits a localized message and owner manages it on a phone" do
    page.current_window.resize_to(320, 700)
    visit localized_contact_path(locale: :fr)

    fill_in "Nom", with: "Ada Lovelace"
    fill_in "Adresse e-mail", with: "ada@example.test"
    fill_in "Objet", with: "Projet Rails"
    fill_in "Message", with: "Parlons de mon projet."

    assert_difference("ContactMessage.count", 1) do
      click_button "Envoyer le message"
      assert_text "Votre message a été enregistré."
    end

    message = ContactMessage.order(:id).last
    assert message.pending?

    sign_in_owner
    visit admin_messages_path
    within "article[data-message-id='#{message.id}']" do
      assert_text "Projet Rails"
      assert_selector "span", text: /pending/i
      click_link "Projet Rails"
    end

    assert_text "Parlons de mon projet."
    click_button "Mark read"
    assert_text "Message marked as read."
    assert message.reload.read?
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
      page.evaluate_script("document.documentElement.clientWidth")
  end
end
