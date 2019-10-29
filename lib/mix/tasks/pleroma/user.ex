# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.User do
  use Mix.Task
  import Mix.Pleroma
  alias Ecto.Changeset
  alias Pleroma.User
  alias Pleroma.UserInviteToken
  alias Pleroma.Web.OAuth

  @shortdoc "Manages Pleroma users"
  @moduledoc File.read!("docs/administration/CLI_tasks/user.md")

  def run(["new", nickname, email | rest]) do
    {options, [], []} =
      OptionParser.parse(
        rest,
        strict: [
          name: :string,
          bio: :string,
          password: :string,
          moderator: :boolean,
          admin: :boolean,
          assume_yes: :boolean
        ],
        aliases: [
          y: :assume_yes
        ]
      )

    name = Keyword.get(options, :name, nickname)
    bio = Keyword.get(options, :bio, "")

    {password, generated_password?} =
      case Keyword.get(options, :password) do
        nil ->
          {:crypto.strong_rand_bytes(16) |> Base.encode64(), true}

        password ->
          {password, false}
      end

    moderator? = Keyword.get(options, :moderator, false)
    admin? = Keyword.get(options, :admin, false)
    assume_yes? = Keyword.get(options, :assume_yes, false)

    shell_info("""
    A user will be created with the following information:
      - nickname: #{nickname}
      - email: #{email}
      - password: #{
      if(generated_password?, do: "[generated; a reset link will be created]", else: password)
    }
      - name: #{name}
      - bio: #{bio}
      - moderator: #{if(moderator?, do: "true", else: "false")}
      - admin: #{if(admin?, do: "true", else: "false")}
    """)

    proceed? = assume_yes? or shell_yes?("Continue?")

    if proceed? do
      start_pleroma()

      params = %{
        nickname: nickname,
        email: email,
        password: password,
        password_confirmation: password,
        name: name,
        bio: bio
      }

      changeset = User.register_changeset(%User{}, params, need_confirmation: false)
      {:ok, _user} = User.register(changeset)

      shell_info("User #{nickname} created")

      if moderator? do
        run(["set", nickname, "--moderator"])
      end

      if admin? do
        run(["set", nickname, "--admin"])
      end

      if generated_password? do
        run(["reset_password", nickname])
      end
    else
      shell_info("User will not be created.")
    end
  end

  def run(["rm", nickname]) do
    start_pleroma()

    with %User{local: true} = user <- User.get_cached_by_nickname(nickname) do
      User.perform(:delete, user)
      shell_info("User #{nickname} deleted.")
    else
      _ ->
        shell_error("No local user #{nickname}")
    end
  end

  def run(["toggle_activated", nickname]) do
    start_pleroma()

    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      {:ok, user} = User.deactivate(user, !user.deactivated)

      shell_info(
        "Activation status of #{nickname}: #{if(user.deactivated, do: "de", else: "")}activated"
      )
    else
      _ ->
        shell_error("No user #{nickname}")
    end
  end

  def run(["reset_password", nickname]) do
    start_pleroma()

    with %User{local: true} = user <- User.get_cached_by_nickname(nickname),
         {:ok, token} <- Pleroma.PasswordResetToken.create_token(user) do
      shell_info("Generated password reset token for #{user.nickname}")

      IO.puts(
        "URL: #{
          Pleroma.Web.Router.Helpers.reset_password_url(
            Pleroma.Web.Endpoint,
            :reset,
            token.token
          )
        }"
      )
    else
      _ ->
        shell_error("No local user #{nickname}")
    end
  end

  def run(["unsubscribe", nickname]) do
    start_pleroma()

    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      shell_info("Deactivating #{user.nickname}")
      User.deactivate(user)

      user
      |> User.get_friends()
      |> Enum.each(fn friend ->
        user = User.get_cached_by_id(user.id)

        shell_info("Unsubscribing #{friend.nickname} from #{user.nickname}")
        User.unfollow(user, friend)
      end)

      :timer.sleep(500)

      user = User.get_cached_by_id(user.id)

      if Enum.empty?(User.get_friends(user)) do
        shell_info("Successfully unsubscribed all followers from #{user.nickname}")
      end
    else
      _ ->
        shell_error("No user #{nickname}")
    end
  end

  def run(["unsubscribe_all_from_instance", instance]) do
    start_pleroma()

    Pleroma.User.Query.build(%{nickname: "@#{instance}"})
    |> Pleroma.RepoStreamer.chunk_stream(500)
    |> Stream.each(fn users ->
      users
      |> Enum.each(fn user ->
        run(["unsubscribe", user.nickname])
      end)
    end)
    |> Stream.run()
  end

  def run(["set", nickname | rest]) do
    start_pleroma()

    {options, [], []} =
      OptionParser.parse(
        rest,
        strict: [
          moderator: :boolean,
          admin: :boolean,
          locked: :boolean
        ]
      )

    with %User{local: true} = user <- User.get_cached_by_nickname(nickname) do
      user =
        case Keyword.get(options, :moderator) do
          nil -> user
          value -> set_moderator(user, value)
        end

      user =
        case Keyword.get(options, :locked) do
          nil -> user
          value -> set_locked(user, value)
        end

      _user =
        case Keyword.get(options, :admin) do
          nil -> user
          value -> set_admin(user, value)
        end
    else
      _ ->
        shell_error("No local user #{nickname}")
    end
  end

  def run(["tag", nickname | tags]) do
    start_pleroma()

    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      user = user |> User.tag(tags)

      shell_info("Tags of #{user.nickname}: #{inspect(tags)}")
    else
      _ ->
        shell_error("Could not change user tags for #{nickname}")
    end
  end

  def run(["untag", nickname | tags]) do
    start_pleroma()

    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      user = user |> User.untag(tags)

      shell_info("Tags of #{user.nickname}: #{inspect(tags)}")
    else
      _ ->
        shell_error("Could not change user tags for #{nickname}")
    end
  end

  def run(["invite" | rest]) do
    {options, [], []} =
      OptionParser.parse(rest,
        strict: [
          expires_at: :string,
          max_use: :integer
        ]
      )

    options =
      options
      |> Keyword.update(:expires_at, {:ok, nil}, fn
        nil -> {:ok, nil}
        val -> Date.from_iso8601(val)
      end)
      |> Enum.into(%{})

    start_pleroma()

    with {:ok, val} <- options[:expires_at],
         options = Map.put(options, :expires_at, val),
         {:ok, invite} <- UserInviteToken.create_invite(options) do
      shell_info("Generated user invite token " <> String.replace(invite.invite_type, "_", " "))

      url =
        Pleroma.Web.Router.Helpers.redirect_url(
          Pleroma.Web.Endpoint,
          :registration_page,
          invite.token
        )

      IO.puts(url)
    else
      error ->
        shell_error("Could not create invite token: #{inspect(error)}")
    end
  end

  def run(["invites"]) do
    start_pleroma()

    shell_info("Invites list:")

    UserInviteToken.list_invites()
    |> Enum.each(fn invite ->
      expire_info =
        with expires_at when not is_nil(expires_at) <- invite.expires_at do
          " | Expires at: #{Date.to_string(expires_at)}"
        end

      using_info =
        with max_use when not is_nil(max_use) <- invite.max_use do
          " | Max use: #{max_use}    Left use: #{max_use - invite.uses}"
        end

      shell_info(
        "ID: #{invite.id} | Token: #{invite.token} | Token type: #{invite.invite_type} | Used: #{
          invite.used
        }#{expire_info}#{using_info}"
      )
    end)
  end

  def run(["revoke_invite", token]) do
    start_pleroma()

    with {:ok, invite} <- UserInviteToken.find_by_token(token),
         {:ok, _} <- UserInviteToken.update_invite(invite, %{used: true}) do
      shell_info("Invite for token #{token} was revoked.")
    else
      _ -> shell_error("No invite found with token #{token}")
    end
  end

  def run(["delete_activities", nickname]) do
    start_pleroma()

    with %User{local: true} = user <- User.get_cached_by_nickname(nickname) do
      User.delete_user_activities(user)
      shell_info("User #{nickname} statuses deleted.")
    else
      _ ->
        shell_error("No local user #{nickname}")
    end
  end

  def run(["toggle_confirmed", nickname]) do
    start_pleroma()

    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      {:ok, user} = User.toggle_confirmation(user)

      message = if user.confirmation_pending, do: "needs", else: "doesn't need"

      shell_info("#{nickname} #{message} confirmation.")
    else
      _ ->
        shell_error("No local user #{nickname}")
    end
  end

  def run(["sign_out", nickname]) do
    start_pleroma()

    with %User{local: true} = user <- User.get_cached_by_nickname(nickname) do
      OAuth.Token.delete_user_tokens(user)
      OAuth.Authorization.delete_user_authorizations(user)

      shell_info("#{nickname} signed out from all apps.")
    else
      _ ->
        shell_error("No local user #{nickname}")
    end
  end

  defp set_moderator(user, value) do
    {:ok, user} =
      user
      |> Changeset.change(%{is_moderator: value})
      |> User.update_and_set_cache()

    shell_info("Moderator status of #{user.nickname}: #{user.is_moderator}")
    user
  end

  defp set_admin(user, value) do
    {:ok, user} =
      user
      |> Changeset.change(%{is_admin: value})
      |> User.update_and_set_cache()

    shell_info("Admin status of #{user.nickname}: #{user.is_admin}")
    user
  end

  defp set_locked(user, value) do
    {:ok, user} =
      user
      |> Changeset.change(%{locked: value})
      |> User.update_and_set_cache()

    shell_info("Locked status of #{user.nickname}: #{user.locked}")
    user
  end
end
