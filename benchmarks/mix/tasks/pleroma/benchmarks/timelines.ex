defmodule Mix.Tasks.Pleroma.Benchmarks.Timelines do
  use Mix.Task

  import Pleroma.LoadTesting.Helper, only: [clean_tables: 0]

  alias Pleroma.Web.CommonAPI
  alias Plug.Conn

  def run(_args) do
    Mix.Pleroma.start_pleroma()

    # Cleaning tables
    clean_tables()

    [{:ok, user} | users] = Pleroma.LoadTesting.Users.generate_users(1000)

    # Let the user make 100 posts

    1..100
    |> Enum.each(fn i -> CommonAPI.post(user, %{"status" => to_string(i)}) end)

    # Let 10 random users post
    posts =
      users
      |> Enum.take_random(10)
      |> Enum.map(fn {:ok, random_user} ->
        {:ok, activity} = CommonAPI.post(random_user, %{"status" => "."})
        activity
      end)

    # let our user repeat them
    posts
    |> Enum.each(fn activity ->
      CommonAPI.repeat(activity.id, user)
    end)

    Benchee.run(
      %{
        "user timeline, no followers" => fn reading_user ->
          conn =
            Phoenix.ConnTest.build_conn()
            |> Conn.assign(:user, reading_user)
            |> Conn.assign(:skip_link_headers, true)

          Pleroma.Web.MastodonAPI.AccountController.statuses(conn, %{"id" => user.id})
        end
      },
      inputs: %{"user" => user, "no user" => nil},
      time: 60
    )

    users
    |> Enum.each(fn {:ok, follower, user} -> Pleroma.User.follow(follower, user) end)

    Benchee.run(
      %{
        "user timeline, all following" => fn reading_user ->
          conn =
            Phoenix.ConnTest.build_conn()
            |> Conn.assign(:user, reading_user)
            |> Conn.assign(:skip_link_headers, true)

          Pleroma.Web.MastodonAPI.AccountController.statuses(conn, %{"id" => user.id})
        end
      },
      inputs: %{"user" => user, "no user" => nil},
      time: 60
    )
  end
end
