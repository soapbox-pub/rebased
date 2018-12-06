defmodule Mix.Tasks.RegisterUser do
  @moduledoc """
  Manually register a local user

  Usage: ``mix register_user <name> <nickname> <email> <bio> <password>``

  Example: ``mix register_user 仮面の告白 lain lain@example.org "blushy-crushy fediverse idol + pleroma dev" pleaseDontHeckLain``
  """

  use Mix.Task
  alias Pleroma.{Repo, User}

  @shortdoc "Register user"
  def run([name, nickname, email, bio, password]) do
    Mix.Task.run("app.start")

    params = %{
      name: name,
      nickname: nickname,
      email: email,
      password: password,
      password_confirmation: password,
      bio: bio
    }

    user = User.register_changeset(%User{}, params)

    Repo.insert!(user)
  end
end
