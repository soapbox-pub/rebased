# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.TwitterAPI do
  alias Pleroma.Emails.Mailer
  alias Pleroma.Emails.UserEmail
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.UserInviteToken

  require Pleroma.Constants

  def register_user(params, opts \\ []) do
    params =
      params
      |> Map.take([
        :nickname,
        :password,
        :captcha_solution,
        :captcha_token,
        :captcha_answer_data,
        :token,
        :email,
        :trusted_app
      ])
      |> Map.put(:bio, User.parse_bio(params[:bio] || ""))
      |> Map.put(:name, params.fullname)
      |> Map.put(:password_confirmation, params[:confirm])

    case validate_captcha(params) do
      :ok ->
        if Pleroma.Config.get([:instance, :registrations_open]) do
          create_user(params, opts)
        else
          create_user_with_invite(params, opts)
        end

      {:error, error} ->
        # I have no idea how this error handling works
        {:error, %{error: Jason.encode!(%{captcha: [error]})}}
    end
  end

  defp validate_captcha(params) do
    if params[:trusted_app] || not Pleroma.Config.get([Pleroma.Captcha, :enabled]) do
      :ok
    else
      Pleroma.Captcha.validate(
        params.captcha_token,
        params.captcha_solution,
        params.captcha_answer_data
      )
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
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
          |> Jason.encode!()

        {:error, %{error: errors}}
    end
  end

  def password_reset(nickname_or_email) do
    with true <- is_binary(nickname_or_email),
         %User{local: true, email: email} = user when not is_nil(email) <-
           User.get_by_nickname_or_email(nickname_or_email),
         {:ok, token_record} <- Pleroma.PasswordResetToken.create_token(user) do
      user
      |> UserEmail.password_reset_email(token_record.token)
      |> Mailer.deliver_async()

      {:ok, :enqueued}
    else
      false ->
        {:error, "bad user identifier"}

      %User{local: true, email: nil} ->
        {:ok, :noop}

      %User{local: false} ->
        {:error, "remote user"}

      nil ->
        {:error, "unknown user"}
    end
  end
end
