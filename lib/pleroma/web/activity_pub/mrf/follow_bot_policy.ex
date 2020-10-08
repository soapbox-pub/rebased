defmodule Pleroma.Web.ActivityPub.MRF.FollowBotPolicy do
  @behaviour Pleroma.Web.ActivityPub.MRF
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  require Logger

  @impl true
  def filter(message) do
    Task.start(fn ->
      follower_nickname = Pleroma.Config.get([:mrf_follow_bot, :follower_nickname])

      with %User{} = follower <- User.get_cached_by_nickname(follower_nickname),
           %{"type" => "Create", "object" => %{"type" => "Note"}} <- message do
        to = Map.get(message, "to", [])
        cc = Map.get(message, "cc", [])
        actor = [message["actor"]]

        Enum.concat([to, cc, actor])
        |> List.flatten()
        |> User.get_all_by_ap_id()
        |> Enum.each(fn user ->
          Logger.info("Checking if #{user.nickname} can be followed")

          with false <- User.following?(follower, user),
               false <- user.locked,
               false <- (user.bio || "") |> String.downcase() |> String.contains?("nobot") do
            Logger.info("Following #{user.nickname}")
            CommonAPI.follow(follower, user)
          end
        end)
      end
    end)

    {:ok, message}
  end

  @impl true
  def describe do
    {:ok, %{}}
  end
end
