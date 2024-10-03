# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.DropPolicy do
  require Logger
  @moduledoc "Drop and log everything received"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def filter(activity) do
    Logger.debug("REJECTING #{inspect(activity)}")
    {:reject, activity}
  end

  @impl true
  def id_filter(id) do
    Logger.debug("REJECTING #{id}")
    false
  end

  @impl true
  def describe, do: {:ok, %{}}
end
