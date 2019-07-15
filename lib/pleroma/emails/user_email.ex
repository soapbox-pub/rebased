# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.UserEmail do
  @moduledoc "User emails"

  import Swoosh.Email

  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Router

  defp instance_config, do: Pleroma.Config.get(:instance)

  defp instance_name, do: instance_config()[:name]

  defp sender do
    email = Keyword.get(instance_config(), :notify_email, instance_config()[:email])
    {instance_name(), email}
  end

  defp recipient(email, nil), do: email
  defp recipient(email, name), do: {name, email}
  defp recipient(%Pleroma.User{} = user), do: recipient(user.email, user.name)

  def password_reset_email(user, token) when is_binary(token) do
    password_reset_url = Router.Helpers.reset_password_url(Endpoint, :reset, token)

    html_body = """
    <h3>Reset your password at #{instance_name()}</h3>
    <p>Someone has requested password change for your account at #{instance_name()}.</p>
    <p>If it was you, visit the following link to proceed: <a href="#{password_reset_url}">reset password</a>.</p>
    <p>If it was someone else, nothing to worry about: your data is secure and your password has not been changed.</p>
    """

    new()
    |> to(recipient(user))
    |> from(sender())
    |> subject("Password reset")
    |> html_body(html_body)
  end

  def user_invitation_email(
        user,
        %Pleroma.UserInviteToken{} = user_invite_token,
        to_email,
        to_name \\ nil
      ) do
    registration_url =
      Router.Helpers.redirect_url(
        Endpoint,
        :registration_page,
        user_invite_token.token
      )

    html_body = """
    <h3>You are invited to #{instance_name()}</h3>
    <p>#{user.name} invites you to join #{instance_name()}, an instance of Pleroma federated social networking platform.</p>
    <p>Click the following link to register: <a href="#{registration_url}">accept invitation</a>.</p>
    """

    new()
    |> to(recipient(to_email, to_name))
    |> from(sender())
    |> subject("Invitation to #{instance_name()}")
    |> html_body(html_body)
  end

  def account_confirmation_email(user) do
    confirmation_url =
      Router.Helpers.confirm_email_url(
        Endpoint,
        :confirm_email,
        user.id,
        to_string(user.info.confirmation_token)
      )

    html_body = """
    <h3>Welcome to #{instance_name()}!</h3>
    <p>Email confirmation is required to activate the account.</p>
    <p>Click the following link to proceed: <a href="#{confirmation_url}">activate your account</a>.</p>
    """

    new()
    |> to(recipient(user))
    |> from(sender())
    |> subject("#{instance_name()} account confirmation")
    |> html_body(html_body)
  end
end
