# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.TwitterAPI do
  import Pleroma.Web.Gettext

  alias Pleroma.Emails.Mailer
  alias Pleroma.Emails.UserEmail
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserInviteToken

  def register_user(params, opts \\ []) do
    params =
      params
      |> Map.take([:email, :token, :password])
      |> Map.put(:bio, params |> Map.get(:bio, "") |> User.parse_bio())
      |> Map.put(:nickname, params[:username])
      |> Map.put(:name, Map.get(params, :fullname, params[:username]))
      |> Map.put(:password_confirmation, params[:password])
      |> Map.put(:registration_reason, params[:reason])
      |> Map.put(:birthday, params[:birthday])

    if Pleroma.Config.get([:instance, :registrations_open]) do
      create_user(params, opts)
    else
      create_user_with_invite(params, opts)
    end
  end

  defp create_user_with_invite(params, opts) do
    with %{token: token} when is_binary(token) <- params,
         %UserInviteToken{} = invite <- Repo.get_by(UserInviteToken, %{token: token}),
         true <- UserInviteToken.valid_invite?(invite) do
      UserInviteToken.update_usage!(invite)
      create_user(params, opts)
    else
      nil -> {:error, "Invalid token"}
      _ -> {:error, "Expired token"}
    end
  end

  defp create_user(params, opts) do
    changeset = User.register_changeset(%User{}, params, opts)

    case User.register(changeset) do
      {:ok, user} ->
        {:ok, user}

      {:error, changeset} ->
        errors =
          changeset
          |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
          |> Jason.encode!()

        {:error, errors}
    end
  end

  def password_reset(nickname_or_email) do
    with true <- is_binary(nickname_or_email),
         %User{local: true, email: email, is_active: true} = user when is_binary(email) <-
           User.get_by_nickname_or_email(nickname_or_email),
         {:ok, token_record} <- Pleroma.PasswordResetToken.create_token(user) do
      user
      |> UserEmail.password_reset_email(token_record.token)
      |> Mailer.deliver_async()

      {:ok, :enqueued}
    else
      _ ->
        {:ok, :noop}
    end
  end

  def validate_captcha(app, params) do
    if app.trusted || not Pleroma.Captcha.enabled?() do
      :ok
    else
      do_validate_captcha(params)
    end
  end

  defp do_validate_captcha(params) do
    with :ok <- validate_captcha_presence(params),
         :ok <-
           Pleroma.Captcha.validate(
             params[:captcha_token],
             params[:captcha_solution],
             params[:captcha_answer_data]
           ) do
      :ok
    else
      {:error, :captcha_error} ->
        captcha_error(dgettext("errors", "CAPTCHA Error"))

      {:error, :invalid} ->
        captcha_error(dgettext("errors", "Invalid CAPTCHA"))

      {:error, :kocaptcha_service_unavailable} ->
        captcha_error(dgettext("errors", "Kocaptcha service unavailable"))

      {:error, :expired} ->
        captcha_error(dgettext("errors", "CAPTCHA expired"))

      {:error, :already_used} ->
        captcha_error(dgettext("errors", "CAPTCHA already used"))

      {:error, :invalid_answer_data} ->
        captcha_error(dgettext("errors", "Invalid answer data"))

      {:error, error} ->
        captcha_error(error)
    end
  end

  defp validate_captcha_presence(params) do
    [:captcha_solution, :captcha_token, :captcha_answer_data]
    |> Enum.find_value(:ok, fn key ->
      unless is_binary(params[key]) do
        error = dgettext("errors", "Invalid CAPTCHA (Missing parameter: %{name})", name: key)
        {:error, error}
      end
    end)
  end

  # For some reason FE expects error message to be a serialized JSON
  defp captcha_error(error), do: {:error, Jason.encode!(%{captcha: [error]})}
end
