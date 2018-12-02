defmodule Mix.Tasks.Pleroma.User do
  use Mix.Task
  alias Pleroma.{Repo, User}

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

  ## Delete the user's account.

      mix pleroma.user rm NICKNAME

  ## Deactivate or activate the user's account.

      mix pleroma.user toggle_activated NICKNAME

  ## Create a password reset link.

      mix pleroma.user reset_password NICKNAME

  ## Set the value of the given user's settings.

      mix pleroma.user set NICKNAME [OPTION...]

  Options:
  - `--locked`/`--no-locked` - whether the user's account is locked
  - `--moderator`/`--no-moderator` - whether the user is a moderator
  - `--admin`/`--no-admin` - whether the user is an admin
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
          admin: :boolean
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

    proceed? = Mix.shell().yes?("Continue?")

    unless not proceed? do
      Mix.Task.run("app.start")

      params =
        %{
          nickname: nickname,
          email: email,
          password: password,
          password_confirmation: password,
          name: name,
          bio: bio
        }
        |> IO.inspect()

      user = User.register_changeset(%User{}, params)
      Repo.insert!(user)

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
    Mix.Task.run("app.start")

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      User.delete(user)
      Mix.shell().info("User #{nickname} deleted.")
    else
      _ ->
        Mix.shell().error("No local user #{nickname}")
    end
  end

  def run(["toggle_activated", nickname]) do
    Mix.Task.run("app.start")

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      User.deactivate(user, !user.info["deactivated"])
      Mix.shell().info("Activation status of #{nickname}: #{user.info["deactivated"]}")
    else
      _ ->
        Mix.shell().error("No local user #{nickname}")
    end
  end

  def run(["reset_password", nickname]) do
    Mix.Task.run("app.start")

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

  def run(["set", nickname | rest]) do
    {options, [], []} =
      OptionParser.parse(
        rest,
        strict: [
          moderator: :boolean,
          admin: :boolean,
          locked: :boolean
        ]
      )

    case Keyword.get(options, :moderator) do
      nil -> nil
      value -> set_moderator(nickname, value)
    end

    case Keyword.get(options, :locked) do
      nil -> nil
      value -> set_locked(nickname, value)
    end

    case Keyword.get(options, :admin) do
      nil -> nil
      value -> set_admin(nickname, value)
    end
  end

  defp set_moderator(nickname, value) do
    Application.ensure_all_started(:pleroma)

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      info =
        user.info
        |> Map.put("is_moderator", value)

      cng = User.info_changeset(user, %{info: info})
      {:ok, user} = User.update_and_set_cache(cng)

      Mix.shell().info("Moderator status of #{nickname}: #{user.info["is_moderator"]}")
    else
      _ ->
        Mix.shell().error("No local user #{nickname}")
    end
  end

  defp set_admin(nickname, value) do
    Application.ensure_all_started(:pleroma)

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      info =
        user.info
        |> Map.put("is_admin", value)

      cng = User.info_changeset(user, %{info: info})
      {:ok, user} = User.update_and_set_cache(cng)

      Mix.shell().info("Admin status of #{nickname}: #{user.info["is_admin"]}")
    else
      _ ->
        Mix.shell().error("No local user #{nickname}")
    end
  end

  defp set_locked(nickname, value) do
    Mix.Ecto.ensure_started(Repo, [])

    with %User{local: true} = user <- User.get_by_nickname(nickname) do
      info =
        user.info
        |> Map.put("locked", value)

      cng = User.info_changeset(user, %{info: info})
      user = Repo.update!(cng)

      IO.puts("Locked status of #{nickname}: #{user.info["locked"]}")
    else
      _ ->
        IO.puts("No local user #{nickname}")
    end
  end
end
