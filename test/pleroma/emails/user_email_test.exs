# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.UserEmailTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Emails.UserEmail
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Router

  import Pleroma.Factory

  test "build password reset email" do
    config = Pleroma.Config.get(:instance)
    user = insert(:user)
    email = UserEmail.password_reset_email(user, "test_token")
    assert email.from == {config[:name], config[:notify_email]}
    assert email.to == [{user.name, user.email}]
    assert email.subject == "Password reset"
    assert email.html_body =~ Router.Helpers.reset_password_url(Endpoint, :reset, "test_token")
  end

  test "build user invitation email" do
    config = Pleroma.Config.get(:instance)
    user = insert(:user)
    token = %Pleroma.UserInviteToken{token: "test-token"}
    email = UserEmail.user_invitation_email(user, token, "test@test.com", "Jonh")
    assert email.from == {config[:name], config[:notify_email]}
    assert email.subject == "Invitation to Pleroma"
    assert email.to == [{"Jonh", "test@test.com"}]

    assert email.html_body =~
             Router.Helpers.redirect_url(Endpoint, :registration_page, token.token)
  end

  test "build account confirmation email" do
    config = Pleroma.Config.get(:instance)
    user = insert(:user, confirmation_token: "conf-token")
    email = UserEmail.account_confirmation_email(user)
    assert email.from == {config[:name], config[:notify_email]}
    assert email.to == [{user.name, user.email}]
    assert email.subject == "#{config[:name]} account confirmation"

    assert email.html_body =~
             Router.Helpers.confirm_email_url(Endpoint, :confirm_email, user.id, "conf-token")
  end

  test "build approval pending email" do
    config = Pleroma.Config.get(:instance)
    user = insert(:user)
    email = UserEmail.approval_pending_email(user)

    assert email.from == {config[:name], config[:notify_email]}
    assert email.to == [{user.name, user.email}]
    assert email.subject == "Your account is awaiting approval"
    assert email.html_body =~ "Awaiting Approval"
  end

  test "email i18n" do
    user = insert(:user, language: "en_test")
    email = UserEmail.approval_pending_email(user)
    assert email.subject == "xxYour account is awaiting approvalxx"
  end

  test "email i18n should fallback to default locale if user language is unsupported" do
    user = insert(:user, language: "unsupported")
    email = UserEmail.approval_pending_email(user)
    assert email.subject == "Your account is awaiting approval"
  end
end
