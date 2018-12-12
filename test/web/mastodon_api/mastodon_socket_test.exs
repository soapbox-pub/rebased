defmodule Pleroma.Web.MastodonApi.MastodonSocketTest do
  use Pleroma.DataCase

  alias Pleroma.Web.{Streamer, CommonAPI}

  import Pleroma.Factory

  test "public is working when non-authenticated" do
    user = insert(:user)

    task =
      Task.async(fn ->
        assert_receive {:text, _}, 4_000
      end)

    fake_socket = %{
      transport_pid: task.pid,
      assigns: %{}
    }

    topics = %{
      "public" => [fake_socket]
    }

    {:ok, activity} = CommonAPI.post(user, %{"status" => "Test"})

    Streamer.push_to_socket(topics, "public", activity)

    Task.await(task)
  end
end
