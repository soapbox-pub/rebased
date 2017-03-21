defmodule Pleroma.Builders.UserBuilder do
  alias Pleroma.{User, Repo}

  def build do
   %User{
      email: "test@example.org",
      name: "Test Name",
      nickname: "testname",
      password_hash: Comeonin.Pbkdf2.hashpwsalt("test"),
      bio: "A tester.",
    }
  end

  def insert do
    Repo.insert(build())
  end
end
