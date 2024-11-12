# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.Policy do
  @callback filter(Pleroma.Activity.t()) :: {:ok | :reject, Pleroma.Activity.t()}
  @callback id_filter(String.t()) :: boolean()
  @callback describe() :: {:ok | :error, map()}
  @callback config_description() :: %{
              optional(:children) => [map()],
              key: atom(),
              related_policy: String.t(),
              label: String.t(),
              description: String.t()
            }
  @callback history_awareness() :: :auto | :manual
  @optional_callbacks config_description: 0, history_awareness: 0, id_filter: 1
end
