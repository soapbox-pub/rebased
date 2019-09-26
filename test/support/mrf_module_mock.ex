# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule MRFModuleMock do
  @behaviour Pleroma.Web.ActivityPub.MRF

  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe, do: {:ok, %{mrf_module_mock: "some config data"}}
end
