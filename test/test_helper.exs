# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Pleroma.Repo, :manual)
Mox.defmock(Pleroma.ReverseProxy.ClientMock, for: Pleroma.ReverseProxy.Client)
{:ok, _} = Application.ensure_all_started(:ex_machina)
