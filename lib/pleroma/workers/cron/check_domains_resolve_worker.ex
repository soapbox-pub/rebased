# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.CheckDomainsResolveWorker do
  @moduledoc """
  The worker to check if alternative domains resolve correctly.
  """

  use Oban.Worker, queue: "check_domain_resolve"

  alias Pleroma.Domain
  alias Pleroma.Repo

  import Ecto.Query

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    domains =
      Domain
      |> select([d], d.id)
      |> Repo.all()

    domains
    |> Enum.map(fn domain_id ->
      Pleroma.Workers.CheckDomainResolveWorker.new(%{
        "op" => "check_domain_resolve",
        "id" => domain_id
      })
    end)
    |> Oban.insert_all()

    :ok
  end
end
