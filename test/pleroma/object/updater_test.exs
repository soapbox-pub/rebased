# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.UpdaterTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  alias Pleroma.Object.Updater

  describe "make_update_object_data/3" do
    setup do
      note = insert(:note)
      %{original_data: note.data}
    end

    test "it makes an updated field", %{original_data: original_data} do
      new_data = Map.put(original_data, "content", "new content")

      date = Pleroma.Web.ActivityPub.Utils.make_date()
      update_object_data = Updater.make_update_object_data(original_data, new_data, date)
      assert %{"updated" => ^date} = update_object_data
    end

    test "it creates formerRepresentations", %{original_data: original_data} do
      new_data = Map.put(original_data, "content", "new content")

      date = Pleroma.Web.ActivityPub.Utils.make_date()
      update_object_data = Updater.make_update_object_data(original_data, new_data, date)

      history_item = original_data |> Map.drop(["id", "formerRepresentations"])

      assert %{
               "formerRepresentations" => %{
                 "totalItems" => 1,
                 "orderedItems" => [^history_item]
               }
             } = update_object_data
    end
  end

  describe "make_new_object_data_from_update_object/2" do
    test "it reuses formerRepresentations if it exists" do
      %{data: original_data} = insert(:note)

      new_data =
        original_data
        |> Map.put("content", "edited")

      date = Pleroma.Web.ActivityPub.Utils.make_date()
      update_object_data = Updater.make_update_object_data(original_data, new_data, date)

      history = update_object_data["formerRepresentations"]["orderedItems"]

      update_object_data =
        update_object_data
        |> put_in(
          ["formerRepresentations", "orderedItems"],
          history ++ [Map.put(original_data, "summary", "additional summary")]
        )
        |> put_in(["formerRepresentations", "totalItems"], length(history) + 1)

      %{
        updated_data: updated_data,
        updated: updated,
        used_history_in_new_object?: used_history_in_new_object?
      } = Updater.make_new_object_data_from_update_object(original_data, update_object_data)

      assert updated
      assert used_history_in_new_object?
      assert updated_data["formerRepresentations"] == update_object_data["formerRepresentations"]
    end
  end
end
