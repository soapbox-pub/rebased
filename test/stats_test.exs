# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.StatsTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Web.CommonAPI

  describe "statuses count" do
    setup do
      user = insert(:user)
      other_user = insert(:user)

      CommonAPI.post(user, %{"visibility" => "public", "status" => "hey"})

      Enum.each(0..1, fn _ ->
        CommonAPI.post(user, %{
          "visibility" => "unlisted",
          "status" => "hey"
        })
      end)

      Enum.each(0..2, fn _ ->
        CommonAPI.post(user, %{
          "visibility" => "direct",
          "status" => "hey @#{other_user.nickname}"
        })
      end)

      Enum.each(0..3, fn _ ->
        CommonAPI.post(user, %{
          "visibility" => "private",
          "status" => "hey"
        })
      end)

      :ok
    end

    test "it returns total number of statuses" do
      data = Pleroma.Stats.get_stat_data()

      assert data.stats.status_count.all == 10
      assert data.stats.status_count.public == 1
      assert data.stats.status_count.unlisted == 2
      assert data.stats.status_count.direct == 3
      assert data.stats.status_count.private == 4
    end
  end
end
