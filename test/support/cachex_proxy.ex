# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.CachexProxy do
  @behaviour Pleroma.Caching

  @impl true
  defdelegate get!(cache, key), to: Cachex

  @impl true
  defdelegate stream!(cache, key), to: Cachex

  @impl true
  defdelegate put(cache, key, value, options), to: Cachex

  @impl true
  defdelegate put(cache, key, value), to: Cachex

  @impl true
  defdelegate get_and_update(cache, key, func), to: Cachex

  @impl true
  defdelegate get(cache, key), to: Cachex

  @impl true
  defdelegate fetch!(cache, key, func), to: Cachex

  @impl true
  defdelegate expire_at(cache, str, num), to: Cachex

  @impl true
  defdelegate exists?(cache, key), to: Cachex

  @impl true
  defdelegate del(cache, key), to: Cachex

  @impl true
  defdelegate execute!(cache, func), to: Cachex
end
