# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReverseProxy.Client do
  @type status :: pos_integer()
  @type header_name :: String.t()
  @type header_value :: String.t()
  @type headers :: [{header_name(), header_value()}]

  @callback request(atom(), String.t(), headers(), String.t(), list()) ::
              {:ok, status(), headers(), reference() | map()}
              | {:ok, status(), headers()}
              | {:ok, reference()}
              | {:error, term()}

  @callback stream_body(map()) :: {:ok, binary(), map()} | :done | {:error, atom() | String.t()}

  @callback close(reference() | pid() | map()) :: :ok
end
