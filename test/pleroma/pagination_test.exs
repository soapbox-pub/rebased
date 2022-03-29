# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.PaginationTest do
  use Pleroma.DataCase, async: true

  import Pleroma.Factory

  alias Pleroma.Object
  alias Pleroma.Pagination

  describe "keyset" do
    setup do
      notes = insert_list(5, :note)

      %{notes: notes}
    end

    test "paginates by min_id", %{notes: notes} do
      id = Enum.at(notes, 2).id

      %{total: total, items: paginated} =
        Pagination.fetch_paginated(Object, %{min_id: id, total: true})

      assert length(paginated) == 2
      assert total == 5
    end

    test "paginates by since_id", %{notes: notes} do
      id = Enum.at(notes, 2).id

      %{total: total, items: paginated} =
        Pagination.fetch_paginated(Object, %{since_id: id, total: true})

      assert length(paginated) == 2
      assert total == 5
    end

    test "paginates by max_id", %{notes: notes} do
      id = Enum.at(notes, 1).id

      %{total: total, items: paginated} =
        Pagination.fetch_paginated(Object, %{max_id: id, total: true})

      assert length(paginated) == 1
      assert total == 5
    end

    test "paginates by min_id & limit", %{notes: notes} do
      id = Enum.at(notes, 2).id

      paginated = Pagination.fetch_paginated(Object, %{min_id: id, limit: 1})

      assert length(paginated) == 1
    end

    test "handles id gracefully", %{notes: notes} do
      id = Enum.at(notes, 1).id

      paginated =
        Pagination.fetch_paginated(Object, %{
          id: "9s99Hq44Cnv8PKBwWG",
          max_id: id,
          limit: 20,
          offset: 0
        })

      assert length(paginated) == 1
    end
  end

  describe "offset" do
    setup do
      notes = insert_list(5, :note)

      %{notes: notes}
    end

    test "paginates by limit" do
      paginated = Pagination.fetch_paginated(Object, %{limit: 2}, :offset)

      assert length(paginated) == 2
    end

    test "paginates by limit & offset" do
      paginated = Pagination.fetch_paginated(Object, %{limit: 2, offset: 4}, :offset)

      assert length(paginated) == 1
    end
  end
end
