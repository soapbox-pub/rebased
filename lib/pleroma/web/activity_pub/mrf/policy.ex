# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.Policy do
  @callback filter(Map.t()) :: {:ok | :reject, Map.t()}
  @callback describe() :: {:ok | :error, Map.t()}
  @callback config_description() :: %{
              optional(:children) => [map()],
              key: atom(),
              related_policy: String.t(),
              label: String.t(),
              description: String.t()
            }
  @optional_callbacks config_description: 0
end
