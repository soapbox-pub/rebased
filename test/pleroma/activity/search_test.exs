# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity.SearchTest do
  use Pleroma.DataCase

  import Pleroma.Factory
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Activity.Search

  test "it finds something" do
    user = insert(:user)
    {:ok, post} = CommonAPI.post(user, %{status: "it's wednesday my dudes"})

    [result] = Search.search(nil, "wednesday")

    assert result.id == post.id
  end

  test "using plainto_tsquery" do
    clear_config([:instance, :search_function], :plain)

    user = insert(:user)
    {:ok, post} = CommonAPI.post(user, %{status: "it's wednesday my dudes"})
    {:ok, _post2} = CommonAPI.post(user, %{status: "it's wednesday my bros"})

    # plainto doesn't understand complex queries
    assert [result] = Search.search(nil, "wednesday -dudes")

    assert result.id == post.id
  end

  test "using websearch_to_tsquery" do
    clear_config([:instance, :search_function], :websearch)

    user = insert(:user)
    {:ok, _post} = CommonAPI.post(user, %{status: "it's wednesday my dudes"})
    {:ok, other_post} = CommonAPI.post(user, %{status: "it's wednesday my bros"})

    assert [result] = Search.search(nil, "wednesday -dudes")

    assert result.id == other_post.id
  end
end
