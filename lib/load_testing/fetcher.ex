defmodule Pleroma.LoadTesting.Fetcher do
  use Pleroma.LoadTesting.Helper

  def fetch_user(user) do
    IO.puts("=================================")

    {time, _value} = :timer.tc(fn -> Repo.get_by(User, id: user.id) end)

    IO.puts("Query user by id: #{to_sec(time)} sec.")

    {time, _value} =
      :timer.tc(fn ->
        Repo.get_by(User, ap_id: user.ap_id)
      end)

    IO.puts("Query user by ap_id: #{to_sec(time)} sec.")

    {time, _value} =
      :timer.tc(fn ->
        Repo.get_by(User, email: user.email)
      end)

    IO.puts("Query user by email: #{to_sec(time)} sec.")

    {time, _value} = :timer.tc(fn -> Repo.get_by(User, nickname: user.nickname) end)

    IO.puts("Query user by nickname: #{to_sec(time)} sec.")
  end

  def query_timelines(user) do
    IO.puts("\n=================================")

    params = %{
      "count" => 20,
      "with_muted" => true,
      "type" => ["Create", "Announce"],
      "blocking_user" => user,
      "muting_user" => user,
      "user" => user
    }

    {time, _} =
      :timer.tc(fn ->
        ActivityPub.ActivityPub.fetch_activities([user.ap_id | user.following], params)
      end)

    IO.puts("Query user home timeline: #{to_sec(time)} sec.")

    params = %{
      "count" => 20,
      "local_only" => true,
      "only_media" => "false",
      "type" => ["Create", "Announce"],
      "with_muted" => "true",
      "blocking_user" => user,
      "muting_user" => user
    }

    {time, _} =
      :timer.tc(fn ->
        ActivityPub.ActivityPub.fetch_public_activities(params)
      end)

    IO.puts("Query user mastodon public timeline: #{to_sec(time)} sec.")

    params = %{
      "count" => 20,
      "only_media" => "false",
      "type" => ["Create", "Announce"],
      "with_muted" => "true",
      "blocking_user" => user,
      "muting_user" => user
    }

    {time, _} =
      :timer.tc(fn ->
        ActivityPub.ActivityPub.fetch_public_activities(params)
      end)

    IO.puts("Query user mastodon federated public timeline: #{to_sec(time)} sec.")
  end

  def query_notifications(user) do
    IO.puts("\n=================================")
    params = %{"count" => "20", "with_muted" => "false"}

    {time, _} =
      :timer.tc(fn -> Pleroma.Web.MastodonAPI.MastodonAPI.get_notifications(user, params) end)

    IO.puts("Query user notifications with out muted: #{to_sec(time)} sec.")

    params = %{"count" => "20", "with_muted" => "true"}

    {time, _} =
      :timer.tc(fn -> Pleroma.Web.MastodonAPI.MastodonAPI.get_notifications(user, params) end)

    IO.puts("Query user notifications with muted: #{to_sec(time)} sec.")
  end

  def query_long_thread(user, activity) do
    IO.puts("\n=================================")

    {time, replies} =
      :timer.tc(fn ->
        Pleroma.Web.ActivityPub.ActivityPub.fetch_activities_for_context(
          activity.data["context"],
          %{
            "blocking_user" => user,
            "user" => user
          }
        )
      end)

    IO.puts("Query long thread with #{length(replies)} replies: #{to_sec(time)} sec.")
  end
end
