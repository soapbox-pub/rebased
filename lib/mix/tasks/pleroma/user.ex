# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.User do
  use Mix.Task
  import Ecto.Changeset
  alias Mix.Tasks.Pleroma.Common
  alias Pleroma.Repo
  alias Pleroma.User

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

      mix pleroma.user invite

  ## Delete the user's account.

      mix pleroma.user rm NICKNAME

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

    unless not proceed? do
      Common.start_pleroma()

      params = %{
        nickname: nickname,
        email: email,
        password: password,
        password_confirmation: password,
        name: name,
        bio: bio
      }

      changeset = User.register_changeset(%User{}, params, confirmed: true)
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

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      User.delete(user)
      Mix.shell().info("User #{nickname} deleted.")
    else
      _ ->
        Mix.shell().error("No local user #{nickname}")
    end
  end

  def run(["toggle_activated", nickname]) do
    Common.start_pleroma()

    with %User{} = user <- User.get_by_nickname(nickname) do
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

    with %User{local: true} = user <- User.get_by_nickname(nickname),
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

    with %User{} = user <- User.get_by_nickname(nickname) do
      Mix.shell().info("Deactivating #{user.nickname}")
      User.deactivate(user)

      {:ok, friends} = User.get_friends(user)

      Enum.each(friends, fn friend ->
        user = Repo.get(User, user.id)

        Mix.shell().info("Unsubscribing #{friend.nickname} from #{user.nickname}")
        User.unfollow(user, friend)
      end)

      :timer.sleep(500)

      user = Repo.get(User, user.id)

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

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
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

    with %User{} = user <- User.get_by_nickname(nickname) do
      user = user |> User.tag(tags)

      Mix.shell().info("Tags of #{user.nickname}: #{inspect(tags)}")
    else
      _ ->
        Mix.shell().error("Could not change user tags for #{nickname}")
    end
  end

  def run(["untag", nickname | tags]) do
    Common.start_pleroma()

    with %User{} = user <- User.get_by_nickname(nickname) do
      user = user |> User.untag(tags)

      Mix.shell().info("Tags of #{user.nickname}: #{inspect(tags)}")
    else
      _ ->
        Mix.shell().error("Could not change user tags for #{nickname}")
    end
  end

  def run(["invite"]) do
    Common.start_pleroma()

    with {:ok, token} <- Pleroma.UserInviteToken.create_token() do
      Mix.shell().info("Generated user invite token")

      url =
        Pleroma.Web.Router.Helpers.redirect_url(
          Pleroma.Web.Endpoint,
          :registration_page,
          token.token
        )

      IO.puts(url)
    else
      _ ->
        Mix.shell().error("Could not create invite token.")
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
