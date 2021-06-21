defmodule Pleroma.Workers.PurgeExpiredFilterTest do
  use Pleroma.DataCase, async: true
  use Oban.Testing, repo: Repo

  import Pleroma.Factory

  test "purges expired filter" do
    %{id: user_id} = insert(:user)

    {:ok, %{id: id}} =
      Pleroma.Filter.create(%{
        user_id: user_id,
        phrase: "cofe",
        context: ["home"],
        expires_in: 600
      })

    assert_enqueued(
      worker: Pleroma.Workers.PurgeExpiredFilter,
      args: %{filter_id: id}
    )

    assert {:ok, %{id: ^id}} =
             perform_job(Pleroma.Workers.PurgeExpiredFilter, %{
               filter_id: id
             })

    assert Repo.aggregate(Pleroma.Filter, :count, :id) == 0
  end
end
