# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.UserEmail do
  @moduledoc "User emails"

  use Phoenix.Swoosh, view: Pleroma.Web.EmailView, layout: {Pleroma.Web.LayoutView, :email}

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

  def password_reset_email(user, password_reset_token) when is_binary(password_reset_token) do
    password_reset_url =
      Router.Helpers.util_url(
        Endpoint,
        :show_password_reset,
        password_reset_token
      )

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

  @doc """
  Email used in digest email notifications
  Includes Mentions and New Followers data
  If there are no mentions (even when new followers exist), the function will return nil
  """
  @spec digest_email(Pleroma.User.t()) :: Swoosh.Email.t() | nil
  def digest_email(user) do
    new_notifications =
      Pleroma.Notification.for_user_since(user, user.last_digest_emailed_at)
      |> Enum.reduce(%{followers: [], mentions: []}, fn
        %{activity: %{data: %{"type" => "Create"}, actor: actor} = activity} = notification,
        acc ->
          new_mention = %{
            data: notification,
            object: Pleroma.Object.normalize(activity),
            from: Pleroma.User.get_by_ap_id(actor)
          }

          %{acc | mentions: [new_mention | acc.mentions]}

        %{activity: %{data: %{"type" => "Follow"}, actor: actor} = activity} = notification,
        acc ->
          new_follower = %{
            data: notification,
            object: Pleroma.Object.normalize(activity),
            from: Pleroma.User.get_by_ap_id(actor)
          }

          %{acc | followers: [new_follower | acc.followers]}

        _, acc ->
          acc
      end)

    with [_ | _] = mentions <- new_notifications.mentions do
      html_data = %{
        instance: instance_name(),
        user: user,
        mentions: mentions,
        followers: new_notifications.followers,
        unsubscribe_link: unsubscribe_url(user, "digest")
      }

      new()
      |> to(recipient(user))
      |> from(sender())
      |> subject("Your digest from #{instance_name()}")
      |> render_body("digest.html", html_data)
    else
      _ ->
        nil
    end
  end

  @doc """
  Generate unsubscribe link for given user and notifications type.
  The link contains JWT token with the data, and subscription can be modified without
  authorization.
  """
  @spec unsubscribe_url(Pleroma.User.t(), String.t()) :: String.t()
  def unsubscribe_url(user, notifications_type) do
    token =
      %{"sub" => user.id, "act" => %{"unsubscribe" => notifications_type}, "exp" => false}
      |> Pleroma.JWT.generate_and_sign!()
      |> Base.encode64()

    Router.Helpers.subscription_url(Pleroma.Web.Endpoint, :unsubscribe, token)
  end
end
