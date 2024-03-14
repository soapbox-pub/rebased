# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SetNicknameWithDomainPlug do
  use Pleroma.Web, :plug

  def init(opts), do: opts

  @impl true
  def perform(%{domain: domain, params: params} = conn, opts) do
    with key <- Keyword.get(opts, :key, "nickname"),
         nickname <- Map.get(params, key),
         false <- String.contains?(nickname, "@"),
         nickname <- nickname <> "@" <> domain.domain,
         params <- Map.put(params, "nickname", nickname) do
      Map.put(conn, :params, params)
    else
      _ -> conn
    end
  end

  def perform(conn, _), do: conn
end
