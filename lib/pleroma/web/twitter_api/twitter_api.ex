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
    token = params["token"]

    params = %{
      nickname: params["nickname"],
      name: params["fullname"],
      bio: User.parse_bio(params["bio"]),
      email: params["email"],
      password: params["password"],
      password_confirmation: params["confirm"],
      captcha_solution: params["captcha_solution"],
      captcha_token: params["captcha_token"],
      captcha_answer_data: params["captcha_answer_data"]
    }

    captcha_enabled = Pleroma.Config.get([Pleroma.Captcha, :enabled])
    # true if captcha is disabled or enabled and valid, false otherwise
    captcha_ok =
      if not captcha_enabled do
        :ok
      else
        Pleroma.Captcha.validate(
          params[:captcha_token],
          params[:captcha_solution],
          params[:captcha_answer_data]
        )
      end

    # Captcha invalid
    if captcha_ok != :ok do
      {:error, error} = captcha_ok
      # I have no idea how this error handling works
      {:error, %{error: Jason.encode!(%{captcha: [error]})}}
    else
      registration_process(
        params,
        %{
          registrations_open: Pleroma.Config.get([:instance, :registrations_open]),
          token: token
        },
        opts
      )
    end
  end

  defp registration_process(params, %{registrations_open: true}, opts) do
    create_user(params, opts)
  end

  defp registration_process(params, %{token: token}, opts) do
    invite =
      unless is_nil(token) do
        Repo.get_by(UserInviteToken, %{token: token})
      end

    valid_invite? = invite && UserInviteToken.valid_invite?(invite)

    case invite do
      nil ->
        {:error, "Invalid token"}

      invite when valid_invite? ->
        UserInviteToken.update_usage!(invite)
        create_user(params, opts)

      _ ->
        {:error, "Expired token"}
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
