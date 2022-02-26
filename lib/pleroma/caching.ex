# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Caching do
  @callback get!(Cachex.cache(), any()) :: any()
  @callback get(Cachex.cache(), any()) :: {atom(), any()}
  @callback put(Cachex.cache(), any(), any(), Keyword.t()) :: {Cachex.status(), boolean()}
  @callback put(Cachex.cache(), any(), any()) :: {Cachex.status(), boolean()}
  @callback fetch!(Cachex.cache(), any(), function() | nil) :: any()
  # @callback del(Cachex.cache(), any(), Keyword.t()) :: {Cachex.status(), boolean()}
  @callback del(Cachex.cache(), any()) :: {Cachex.status(), boolean()}
  @callback stream!(Cachex.cache(), any()) :: Enumerable.t()
  @callback expire_at(Cachex.cache(), binary(), number()) :: {Cachex.status(), boolean()}
  @callback exists?(Cachex.cache(), any()) :: {Cachex.status(), boolean()}
  @callback execute!(Cachex.cache(), function()) :: any()
  @callback get_and_update(Cachex.cache(), any(), function()) ::
              {:commit | :ignore, any()}
end
