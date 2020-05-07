defmodule Pleroma.Builders.UserBuilder do
  alias Pleroma.Repo
  alias Pleroma.User

  def build(data \\ %{}) do
    user = %User{
      email: "test@example.org",
      name: "Test Name",
      nickname: "testname",
      password_hash: Comeonin.Pbkdf2.hashpwsalt("test"),
      bio: "A tester.",
      ap_id: "some id",
      last_digest_emailed_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      multi_factor_authentication_settings: %Pleroma.MFA.Settings{},
      notification_settings: %Pleroma.User.NotificationSetting{}
    }

    Map.merge(user, data)
  end

  def insert(data \\ %{}) do
    {:ok, user} = Repo.insert(build(data))
    User.invalidate_cache(user)
    {:ok, user}
  end
end
