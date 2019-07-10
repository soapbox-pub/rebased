# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReverseProxy.Client do
  @callback request(atom(), String.t(), [tuple()], String.t(), list()) ::
              {:ok, pos_integer(), [tuple()], reference() | map()}
              | {:ok, pos_integer(), [tuple()]}
              | {:ok, reference()}
              | {:error, term()}

  @callback stream_body(reference() | pid() | map()) ::
              {:ok, binary()} | :done | {:error, String.t()}

  @callback close(reference() | pid() | map()) :: :ok

  def request(method, url, headers, "", opts \\ []) do
    client().request(method, url, headers, "", opts)
  end

  def stream_body(ref), do: client().stream_body(ref)

  def close(ref), do: client().close(ref)

  defp client do
    Pleroma.Config.get([Pleroma.ReverseProxy.Client], :hackney)
  end
end
