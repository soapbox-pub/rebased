defmodule Mix.Tasks.RegisterUser do
  use Mix.Task
  import Mix.Ecto
  alias Pleroma.{Repo, User}

  @shortdoc "Register user"
  def run([name, nickname, email, bio, password]) do
    ensure_started(Repo, [])

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
