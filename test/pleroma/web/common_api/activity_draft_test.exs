# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.ActivityDraftTest do
  use Pleroma.DataCase

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.ActivityDraft

  import Pleroma.Factory

  test "create/2 with a quote post" do
    user = insert(:user)

    {:ok, direct} = CommonAPI.post(user, %{status: ".", visibility: "direct"})
    {:ok, private} = CommonAPI.post(user, %{status: ".", visibility: "private"})
    {:ok, unlisted} = CommonAPI.post(user, %{status: ".", visibility: "unlisted"})
    {:ok, public} = CommonAPI.post(user, %{status: ".", visibility: "public"})

    {:error, _} = ActivityDraft.create(user, %{status: "nice", quote_id: direct.id})
    {:error, _} = ActivityDraft.create(user, %{status: "nice", quote_id: private.id})
    {:ok, _} = ActivityDraft.create(user, %{status: "nice", quote_id: unlisted.id})
    {:ok, _} = ActivityDraft.create(user, %{status: "nice", quote_id: public.id})
  end
end
