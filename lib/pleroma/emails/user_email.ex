# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.UserEmail do
  @moduledoc "User emails"

  use Phoenix.Swoosh, view: Pleroma.Web.EmailView, layout: {Pleroma.Web.LayoutView, :email}

  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Router

  defp instance_name, do: Config.get([:instance, :name])

  defp sender do
    email = Config.get([:instance, :notify_email]) || Config.get([:instance, :email])
    {instance_name(), email}
  end

  defp recipient(email, nil), do: email
  defp recipient(email, name), do: {name, email}
  defp recipient(%User{} = user), do: recipient(user.email, user.name)

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
        to_string(user.confirmation_token)
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
  @spec digest_email(User.t()) :: Swoosh.Email.t() | nil
  def digest_email(user) do
    notifications = Pleroma.Notification.for_user_since(user, user.last_digest_emailed_at)

    mentions =
      notifications
      |> Enum.filter(&(&1.activity.data["type"] == "Create"))
      |> Enum.map(fn notification ->
        object = Pleroma.Object.normalize(notification.activity)
        object = update_in(object.data["content"], &format_links/1)

        %{
          data: notification,
          object: object,
          from: User.get_by_ap_id(notification.activity.actor)
        }
      end)

    followers =
      notifications
      |> Enum.filter(&(&1.activity.data["type"] == "Follow"))
      |> Enum.map(fn notification ->
        %{
          data: notification,
          object: Pleroma.Object.normalize(notification.activity),
          from: User.get_by_ap_id(notification.activity.actor)
        }
      end)

    unless Enum.empty?(mentions) do
      styling = Config.get([__MODULE__, :styling])
      logo = Config.get([__MODULE__, :logo])

      html_data = %{
        instance: instance_name(),
        user: user,
        mentions: mentions,
        followers: followers,
        unsubscribe_link: unsubscribe_url(user, "digest"),
        styling: styling
      }

      logo_path =
        if is_nil(logo) do
          Path.join(:code.priv_dir(:pleroma), "static/static/logo.png")
        else
          Path.join(Config.get([:instance, :static_dir]), logo)
        end

      new()
      |> to(recipient(user))
      |> from(sender())
      |> subject("Your digest from #{instance_name()}")
      |> put_layout(false)
      |> render_body("digest.html", html_data)
      |> attachment(Swoosh.Attachment.new(logo_path, filename: "logo.png", type: :inline))
    end
  end

  defp format_links(str) do
    re = ~r/<a.+href=['"].*>/iU
    %{link_color: color} = Config.get([__MODULE__, :styling])

    Regex.replace(re, str, fn link ->
      String.replace(link, "<a", "<a style=\"color: #{color};text-decoration: none;\"")
    end)
  end

  @doc """
  Generate unsubscribe link for given user and notifications type.
  The link contains JWT token with the data, and subscription can be modified without
  authorization.
  """
  @spec unsubscribe_url(User.t(), String.t()) :: String.t()
  def unsubscribe_url(user, notifications_type) do
    token =
      %{"sub" => user.id, "act" => %{"unsubscribe" => notifications_type}, "exp" => false}
      |> Pleroma.JWT.generate_and_sign!()
      |> Base.encode64()

    Router.Helpers.subscription_url(Endpoint, :unsubscribe, token)
  end
end
