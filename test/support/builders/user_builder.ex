defmodule Pleroma.Builders.UserBuilder do
  alias Pleroma.{User, Repo}

  def build(data \\ %{}) do
    user = %User{
      email: "test@example.org",
      name: "Test Name",
      nickname: "testname",
      password_hash: Comeonin.Pbkdf2.hashpwsalt("test"),
      bio: "A tester.",
      ap_id: "some id"
    }
    Map.merge(user, data)
  end

  def insert(data \\ %{}) do
    Repo.insert(build(data))
  end
end
