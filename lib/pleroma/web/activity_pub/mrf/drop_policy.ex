# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.DropPolicy do
  require Logger
  @moduledoc "Drop and log everything received"
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(object) do
    Logger.info("REJECTING #{inspect(object)}")
    {:reject, object}
  end

  @impl true
  def describe, do: {:ok, %{}}
end
