# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.StateTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.CommonAPI

  describe "status visibility count" do
    test "on new status" do
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

      assert %{direct: 3, private: 4, public: 1, unlisted: 2} =
               Pleroma.Stats.get_status_visibility_count()
    end

    test "on status delete" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"visibility" => "public", "status" => "hey"})
      assert %{public: 1} = Pleroma.Stats.get_status_visibility_count()
      CommonAPI.delete(activity.id, user)
      assert %{public: 0} = Pleroma.Stats.get_status_visibility_count()
    end

    test "on status visibility update" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"visibility" => "public", "status" => "hey"})
      assert %{public: 1, private: 0} = Pleroma.Stats.get_status_visibility_count()
      {:ok, _} = CommonAPI.update_activity_scope(activity.id, %{"visibility" => "private"})
      assert %{public: 0, private: 1} = Pleroma.Stats.get_status_visibility_count()
    end

    test "doesn't count unrelated activities" do
      user = insert(:user)
      other_user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"visibility" => "public", "status" => "hey"})
      _ = CommonAPI.follow(user, other_user)
      CommonAPI.favorite(activity.id, other_user)
      CommonAPI.repeat(activity.id, other_user)

      assert %{direct: 0, private: 0, public: 1, unlisted: 0} =
               Pleroma.Stats.get_status_visibility_count()
    end
  end
end
