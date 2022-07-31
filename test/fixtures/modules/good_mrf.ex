# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Fixtures.Modules.GoodMRF do
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def filter(a), do: {:ok, a}

  @impl true
  def describe, do: %{}

  @impl true
  def config_description do
    %{
      key: :good_mrf,
      related_policy: "Fixtures.Modules.GoodMRF",
      label: "Good MRF",
      description: "Some description"
    }
  end
end
