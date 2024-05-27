# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.Getting do
  @callback get(any()) :: any()
  @callback get(any(), any()) :: any()

  def get(key), do: get(key, nil)
  def get(key, default), do: impl().get(key, default)

  def impl do
    Application.get_env(:pleroma, :config_impl, Pleroma.Config)
  end
end
