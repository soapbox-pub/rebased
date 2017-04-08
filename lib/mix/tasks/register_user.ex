defmodule Mix.Tasks.RegisterUser do
  use Mix.Task
  import Mix.Ecto
  alias Pleroma.{Repo, User}

  @shortdoc "Register user"
  def run([name, nickname, email, bio, password]) do
    ensure_started(Repo, [])
    user = %User{
      name: name,
      nickname: nickname,
      email: email,
      password_hash: Comeonin.Pbkdf2.hashpwsalt(password),
      bio: bio
    }

    user = %{ user | ap_id: User.ap_id(user) }

    Repo.insert!(user)
  end
end
