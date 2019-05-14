# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.User do
  use Mix.Task
  import Ecto.Changeset
  alias Mix.Tasks.Pleroma.Common
  alias Pleroma.User
  alias Pleroma.UserInviteToken

  @shortdoc "Manages Pleroma users"
  @moduledoc """
  Manages Pleroma users.

  ## Create a new user.

      mix pleroma.user new NICKNAME EMAIL [OPTION...]

  Options:
  - `--name NAME` - the user's name (i.e., "Lain Iwakura")
  - `--bio BIO` - the user's bio
  - `--password PASSWORD` - the user's password
  - `--moderator`/`--no-moderator` - whether the user is a moderator
  - `--admin`/`--no-admin` - whether the user is an admin
  - `-y`, `--assume-yes`/`--no-assume-yes` - whether to assume yes to all questions

  ## Generate an invite link.

      mix pleroma.user invite [OPTION...]

    Options:
    - `--expires_at DATE` - last day on which token is active (e.g. "2019-04-05")
    - `--max_use NUMBER` - maximum numbers of token uses

  ## List generated invites

      mix pleroma.user invites

  ## Revoke invite

      mix pleroma.user revoke_invite TOKEN OR TOKEN_ID

  ## Delete the user's account.

      mix pleroma.user rm NICKNAME

  ## Delete the user's activities.

      mix pleroma.user delete_activities NICKNAME

  ## Deactivate or activate the user's account.

      mix pleroma.user toggle_activated NICKNAME

  ## Unsubscribe local users from user's account and deactivate it

      mix pleroma.user unsubscribe NICKNAME

  ## Create a password reset link.

      mix pleroma.user reset_password NICKNAME

  ## Set the value of the given user's settings.

      mix pleroma.user set NICKNAME [OPTION...]

  Options:
  - `--locked`/`--no-locked` - whether the user's account is locked
  - `--moderator`/`--no-moderator` - whether the user is a moderator
  - `--admin`/`--no-admin` - whether the user is an admin

  ## Add tags to a user.

      mix pleroma.user tag NICKNAME TAGS

  ## Delete tags from a user.

      mix pleroma.user untag NICKNAME TAGS
  """
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

    Mix.shell().info("""
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

    proceed? = assume_yes? or Mix.shell().yes?("Continue?")

    if proceed? do
      Common.start_pleroma()

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

      Mix.shell().info("User #{nickname} created")

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
      Mix.shell().info("User will not be created.")
    end
  end

  def run(["rm", nickname]) do
    Common.start_pleroma()

    with %User{local: true} = user <- User.get_cached_by_nickname(nickname) do
      User.perform(:delete, user)
      Mix.shell().info("User #{nickname} deleted.")
    else
      _ ->
        Mix.shell().error("No local user #{nickname}")
    end
  end

  def run(["toggle_activated", nickname]) do
    Common.start_pleroma()

    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      {:ok, user} = User.deactivate(user, !user.info.deactivated)

      Mix.shell().info(
        "Activation status of #{nickname}: #{if(user.info.deactivated, do: "de", else: "")}activated"
      )
    else
      _ ->
        Mix.shell().error("No user #{nickname}")
    end
  end

  def run(["reset_password", nickname]) do
    Common.start_pleroma()

    with %User{local: true} = user <- User.get_cached_by_nickname(nickname),
         {:ok, token} <- Pleroma.PasswordResetToken.create_token(user) do
      Mix.shell().info("Generated password reset token for #{user.nickname}")

      IO.puts(
        "URL: #{
          Pleroma.Web.Router.Helpers.util_url(
            Pleroma.Web.Endpoint,
            :show_password_reset,
            token.token
          )
        }"
      )
    else
      _ ->
        Mix.shell().error("No local user #{nickname}")
    end
  end

  def run(["unsubscribe", nickname]) do
    Common.start_pleroma()

    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      Mix.shell().info("Deactivating #{user.nickname}")
      User.deactivate(user)

      {:ok, friends} = User.get_friends(user)

      Enum.each(friends, fn friend ->
        user = User.get_cached_by_id(user.id)

        Mix.shell().info("Unsubscribing #{friend.nickname} from #{user.nickname}")
        User.unfollow(user, friend)
      end)

      :timer.sleep(500)

      user = User.get_cached_by_id(user.id)

      if Enum.empty?(user.following) do
        Mix.shell().info("Successfully unsubscribed all followers from #{user.nickname}")
      end
    else
      _ ->
        Mix.shell().error("No user #{nickname}")
    end
  end

  def run(["set", nickname | rest]) do
    Common.start_pleroma()

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
        Mix.shell().error("No local user #{nickname}")
    end
  end

  def run(["tag", nickname | tags]) do
    Common.start_pleroma()

    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      user = user |> User.tag(tags)

      Mix.shell().info("Tags of #{user.nickname}: #{inspect(tags)}")
    else
      _ ->
        Mix.shell().error("Could not change user tags for #{nickname}")
    end
  end

  def run(["untag", nickname | tags]) do
    Common.start_pleroma()

    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      user = user |> User.untag(tags)

      Mix.shell().info("Tags of #{user.nickname}: #{inspect(tags)}")
    else
      _ ->
        Mix.shell().error("Could not change user tags for #{nickname}")
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

    Common.start_pleroma()

    with {:ok, val} <- options[:expires_at],
         options = Map.put(options, :expires_at, val),
         {:ok, invite} <- UserInviteToken.create_invite(options) do
      Mix.shell().info(
        "Generated user invite token " <> String.replace(invite.invite_type, "_", " ")
      )

      url =
        Pleroma.Web.Router.Helpers.redirect_url(
          Pleroma.Web.Endpoint,
          :registration_page,
          invite.token
        )

      IO.puts(url)
    else
      error ->
        Mix.shell().error("Could not create invite token: #{inspect(error)}")
    end
  end

  def run(["invites"]) do
    Common.start_pleroma()

    Mix.shell().info("Invites list:")

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

      Mix.shell().info(
        "ID: #{invite.id} | Token: #{invite.token} | Token type: #{invite.invite_type} | Used: #{
          invite.used
        }#{expire_info}#{using_info}"
      )
    end)
  end

  def run(["revoke_invite", token]) do
    Common.start_pleroma()

    with {:ok, invite} <- UserInviteToken.find_by_token(token),
         {:ok, _} <- UserInviteToken.update_invite(invite, %{used: true}) do
      Mix.shell().info("Invite for token #{token} was revoked.")
    else
      _ -> Mix.shell().error("No invite found with token #{token}")
    end
  end

  def run(["delete_activities", nickname]) do
    Common.start_pleroma()

    with %User{local: true} = user <- User.get_cached_by_nickname(nickname) do
      {:ok, _} = User.delete_user_activities(user)
      Mix.shell().info("User #{nickname} statuses deleted.")
    else
      _ ->
        Mix.shell().error("No local user #{nickname}")
    end
  end

  defp set_moderator(user, value) do
    info_cng = User.Info.admin_api_update(user.info, %{is_moderator: value})

    user_cng =
      Ecto.Changeset.change(user)
      |> put_embed(:info, info_cng)

    {:ok, user} = User.update_and_set_cache(user_cng)

    Mix.shell().info("Moderator status of #{user.nickname}: #{user.info.is_moderator}")
    user
  end

  defp set_admin(user, value) do
    info_cng = User.Info.admin_api_update(user.info, %{is_admin: value})

    user_cng =
      Ecto.Changeset.change(user)
      |> put_embed(:info, info_cng)

    {:ok, user} = User.update_and_set_cache(user_cng)

    Mix.shell().info("Admin status of #{user.nickname}: #{user.info.is_admin}")
    user
  end

  defp set_locked(user, value) do
    info_cng = User.Info.user_upgrade(user.info, %{locked: value})

    user_cng =
      Ecto.Changeset.change(user)
      |> put_embed(:info, info_cng)

    {:ok, user} = User.update_and_set_cache(user_cng)

    Mix.shell().info("Locked status of #{user.nickname}: #{user.info.locked}")
    user
  end
end
