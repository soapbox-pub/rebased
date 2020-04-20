# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# A test controller reachable only in :test env.
# Serves to test OAuth scopes check skipping / enforcement.
defmodule Pleroma.Tests.OAuthTestController do
  @moduledoc false

  use Pleroma.Web, :controller

  alias Pleroma.Plugs.OAuthScopesPlug

  plug(:skip_plug, OAuthScopesPlug when action == :skipped_oauth)

  plug(OAuthScopesPlug, %{scopes: ["read"]} when action != :missed_oauth)

  def skipped_oauth(conn, _params) do
    noop(conn)
  end

  def performed_oauth(conn, _params) do
    noop(conn)
  end

  def missed_oauth(conn, _params) do
    noop(conn)
  end

  defp noop(conn), do: json(conn, %{})
end
