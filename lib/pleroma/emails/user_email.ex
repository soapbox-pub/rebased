# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.UserEmail do
  @moduledoc "User emails"

  require Pleroma.Web.Gettext

  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Gettext
  alias Pleroma.Web.Router

  import Swoosh.Email
  import Phoenix.Swoosh, except: [render_body: 3]
  import Pleroma.Config.Helpers, only: [instance_name: 0, sender: 0]

  def render_body(email, template, assigns \\ %{}) do
    email
    |> put_new_layout({Pleroma.Web.LayoutView, :email})
    |> put_new_view(Pleroma.Web.EmailView)
    |> Phoenix.Swoosh.render_body(template, assigns)
  end

  defp recipient(email, nil), do: email
  defp recipient(email, name), do: {name, email}
  defp recipient(%User{} = user), do: recipient(user.email, user.name)

  @spec welcome(User.t(), map()) :: Swoosh.Email.t()
  def welcome(user, opts \\ %{}) do
    Gettext.with_locale_or_default user.language do
      new()
      |> to(recipient(user))
      |> from(Map.get(opts, :sender, sender()))
      |> subject(
        Map.get(
          opts,
          :subject,
          Gettext.dpgettext(
            "static_pages",
            "welcome email subject",
            "Welcome to %{instance_name}!",
            instance_name: instance_name()
          )
        )
      )
      |> html_body(
        Map.get(
          opts,
          :html,
          Gettext.dpgettext(
            "static_pages",
            "welcome email html body",
            "Welcome to %{instance_name}!",
            instance_name: instance_name()
          )
        )
      )
      |> text_body(
        Map.get(
          opts,
          :text,
          Gettext.dpgettext(
            "static_pages",
            "welcome email text body",
            "Welcome to %{instance_name}!",
            instance_name: instance_name()
          )
        )
      )
    end
  end

  def password_reset_email(user, token) when is_binary(token) do
    Gettext.with_locale_or_default user.language do
      password_reset_url = Router.Helpers.reset_password_url(Endpoint, :reset, token)

      html_body =
        Gettext.dpgettext(
          "static_pages",
          "password reset email body",
          """
          <h3>Reset your password at %{instance_name}</h3>
          <p>Someone has requested password change for your account at %{instance_name}.</p>
          <p>If it was you, visit the following link to proceed: <a href="%{password_reset_url}">reset password</a>.</p>
          <p>If it was someone else, nothing to worry about: your data is secure and your password has not been changed.</p>
          """,
          instance_name: instance_name(),
          password_reset_url: password_reset_url
        )

      new()
      |> to(recipient(user))
      |> from(sender())
      |> subject(
        Gettext.dpgettext("static_pages", "password reset email subject", "Password reset")
      )
      |> html_body(html_body)
    end
  end

  def user_invitation_email(
        user,
        %Pleroma.UserInviteToken{} = user_invite_token,
        to_email,
        to_name \\ nil
      ) do
    Gettext.with_locale_or_default user.language do
      registration_url =
        Router.Helpers.redirect_url(
          Endpoint,
          :registration_page,
          user_invite_token.token
        )

      html_body =
        Gettext.dpgettext(
          "static_pages",
          "user invitation email body",
          """
          <h3>You are invited to %{instance_name}</h3>
          <p>%{inviter_name} invites you to join %{instance_name}, an instance of Pleroma federated social networking platform.</p>
          <p>Click the following link to register: <a href="%{registration_url}">accept invitation</a>.</p>
          """,
          instance_name: instance_name(),
          inviter_name: user.name,
          registration_url: registration_url
        )

      new()
      |> to(recipient(to_email, to_name))
      |> from(sender())
      |> subject(
        Gettext.dpgettext(
          "static_pages",
          "user invitation email subject",
          "Invitation to %{instance_name}",
          instance_name: instance_name()
        )
      )
      |> html_body(html_body)
    end
  end

  def account_confirmation_email(user) do
    Gettext.with_locale_or_default user.language do
      confirmation_url =
        Router.Helpers.confirm_email_url(
          Endpoint,
          :confirm_email,
          user.id,
          to_string(user.confirmation_token)
        )

      html_body =
        Gettext.dpgettext(
          "static_pages",
          "confirmation email body",
          """
          <h3>Thank you for registering on %{instance_name}</h3>
          <p>Email confirmation is required to activate the account.</p>
          <p>Please click the following link to <a href="%{confirmation_url}">activate your account</a>.</p>
          """,
          instance_name: instance_name(),
          confirmation_url: confirmation_url
        )

      new()
      |> to(recipient(user))
      |> from(sender())
      |> subject(
        Gettext.dpgettext(
          "static_pages",
          "confirmation email subject",
          "%{instance_name} account confirmation",
          instance_name: instance_name()
        )
      )
      |> html_body(html_body)
    end
  end

  def approval_pending_email(user) do
    Gettext.with_locale_or_default user.language do
      html_body =
        Gettext.dpgettext(
          "static_pages",
          "approval pending email body",
          """
          <h3>Awaiting Approval</h3>
          <p>Your account at %{instance_name} is being reviewed by staff. You will receive another email once your account is approved.</p>
          """,
          instance_name: instance_name()
        )

      new()
      |> to(recipient(user))
      |> from(sender())
      |> subject(
        Gettext.dpgettext(
          "static_pages",
          "approval pending email subject",
          "Your account is awaiting approval"
        )
      )
      |> html_body(html_body)
    end
  end

  def successful_registration_email(user) do
    Gettext.with_locale_or_default user.language do
      html_body =
        Gettext.dpgettext(
          "static_pages",
          "successful registration email body",
          """
          <h3>Hello @%{nickname},</h3>
          <p>Your account at %{instance_name} has been registered successfully.</p>
          <p>No further action is required to activate your account.</p>
          """,
          nickname: user.nickname,
          instance_name: instance_name()
        )

      new()
      |> to(recipient(user))
      |> from(sender())
      |> subject(
        Gettext.dpgettext(
          "static_pages",
          "successful registration email subject",
          "Account registered on %{instance_name}",
          instance_name: instance_name()
        )
      )
      |> html_body(html_body)
    end
  end

  @doc """
  Email used in digest email notifications
  Includes Mentions and New Followers data
  If there are no mentions (even when new followers exist), the function will return nil
  """
  @spec digest_email(User.t()) :: Swoosh.Email.t() | nil
  def digest_email(user) do
    Gettext.with_locale_or_default user.language do
      notifications = Pleroma.Notification.for_user_since(user, user.last_digest_emailed_at)

      mentions =
        notifications
        |> Enum.filter(&(&1.activity.data["type"] == "Create"))
        |> Enum.map(fn notification ->
          object = Pleroma.Object.normalize(notification.activity, fetch: false)

          if not is_nil(object) do
            object = update_in(object.data["content"], &format_links/1)

            %{
              data: notification,
              object: object,
              from: User.get_by_ap_id(notification.activity.actor)
            }
          end
        end)
        |> Enum.filter(& &1)

      followers =
        notifications
        |> Enum.filter(&(&1.activity.data["type"] == "Follow"))
        |> Enum.map(fn notification ->
          from = User.get_by_ap_id(notification.activity.actor)

          if not is_nil(from) do
            %{
              data: notification,
              object: Pleroma.Object.normalize(notification.activity, fetch: false),
              from: User.get_by_ap_id(notification.activity.actor)
            }
          end
        end)
        |> Enum.filter(& &1)

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
            Path.join(:code.priv_dir(:pleroma), "static/static/logo.svg")
          else
            Path.join(Config.get([:instance, :static_dir]), logo)
          end

        new()
        |> to(recipient(user))
        |> from(sender())
        |> subject(
          Gettext.dpgettext(
            "static_pages",
            "digest email subject",
            "Your digest from %{instance_name}",
            instance_name: instance_name()
          )
        )
        |> put_layout(false)
        |> render_body("digest.html", html_data)
        |> attachment(Swoosh.Attachment.new(logo_path, filename: "logo.svg", type: :inline))
      end
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

  def backup_is_ready_email(backup, admin_user_id \\ nil) do
    %{user: user} = Pleroma.Repo.preload(backup, :user)

    Gettext.with_locale_or_default user.language do
      download_url = Pleroma.Web.PleromaAPI.BackupView.download_url(backup)

      html_body =
        if is_nil(admin_user_id) do
          Gettext.dpgettext(
            "static_pages",
            "account archive email body - self-requested",
            """
            <p>You requested a full backup of your Pleroma account. It's ready for download:</p>
            <p><a href="%{download_url}">%{download_url}</a></p>
            """,
            download_url: download_url
          )
        else
          admin = Pleroma.Repo.get(User, admin_user_id)

          Gettext.dpgettext(
            "static_pages",
            "account archive email body - admin requested",
            """
            <p>Admin @%{admin_nickname} requested a full backup of your Pleroma account. It's ready for download:</p>
            <p><a href="%{download_url}">%{download_url}</a></p>
            """,
            admin_nickname: admin.nickname,
            download_url: download_url
          )
        end

      new()
      |> to(recipient(user))
      |> from(sender())
      |> subject(
        Gettext.dpgettext(
          "static_pages",
          "account archive email subject",
          "Your account archive is ready"
        )
      )
      |> html_body(html_body)
    end
  end
end
