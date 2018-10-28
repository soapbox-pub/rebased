defmodule Mix.Tasks.UnsubscribeUser do
  use Mix.Task
  alias Pleroma.{User, Repo}
  require Logger

  @shortdoc "Unsubscribe all users from a target and then deactivate them"
  def run([nickname]) do
    Mix.Task.run("app.start")

    with %User{} = user <- User.get_by_nickname(nickname) do
      Logger.info("Deactivating #{user.nickname}")
      User.deactivate(user)

      {:ok, friends} = User.get_friends(user)

      Enum.each(friends, fn friend ->
        user = Repo.get(User, user.id)

        Logger.info("Unsubscribing #{friend.nickname} from #{user.nickname}")
        User.unfollow(user, friend)
      end)

      :timer.sleep(500)

      user = Repo.get(User, user.id)

      if length(user.following) == 0 do
        Logger.info("Successfully unsubscribed all followers from #{user.nickname}")
      end
    end
  end
end
