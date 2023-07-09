# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload.Providers.TimelineTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Preload.Providers.Timelines

  @public_url "/api/v1/timelines/public"

  describe "unauthenticated timeliness when restricted" do
    setup do: clear_config([:restrict_unauthenticated, :timelines, :local], true)
    setup do: clear_config([:restrict_unauthenticated, :timelines, :federated], true)

    test "return nothing" do
      tl_data = Timelines.generate_terms(%{})

      refute Map.has_key?(tl_data, "/api/v1/timelines/public")
    end
  end

  describe "unauthenticated timeliness when unrestricted" do
    setup do: clear_config([:restrict_unauthenticated, :timelines, :local], false)
    setup do: clear_config([:restrict_unauthenticated, :timelines, :federated], false)

    setup do: {:ok, user: insert(:user)}

    test "returns the timeline when not restricted" do
      assert Timelines.generate_terms(%{})
             |> Map.has_key?(@public_url)
    end

    test "returns public items", %{user: user} do
      {:ok, _} = CommonAPI.post(user, %{status: "it's post 1!"})
      {:ok, _} = CommonAPI.post(user, %{status: "it's post 2!"})
      {:ok, _} = CommonAPI.post(user, %{status: "it's post 3!"})

      assert Timelines.generate_terms(%{})
             |> Map.fetch!(@public_url)
             |> Enum.count() == 3
    end

    test "does not return non-public items", %{user: user} do
      {:ok, _} = CommonAPI.post(user, %{status: "it's post 1!", visibility: "unlisted"})
      {:ok, _} = CommonAPI.post(user, %{status: "it's post 2!", visibility: "direct"})
      {:ok, _} = CommonAPI.post(user, %{status: "it's post 3!"})

      assert Timelines.generate_terms(%{})
             |> Map.fetch!(@public_url)
             |> Enum.count() == 1
    end
  end
end
