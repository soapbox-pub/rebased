# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.JWT do
  use Joken.Config

  @impl true
  def token_config do
    default_claims(skip: [:aud])
    |> add_claim("aud", &Pleroma.Web.Endpoint.url/0, &(&1 == Pleroma.Web.Endpoint.url()))
  end
end
