# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Maintenance do
  alias Pleroma.Repo
  require Logger

  def vacuum(args) do
    case args do
      "analyze" ->
        Logger.info("Running VACUUM ANALYZE.")

        Repo.query!(
          "vacuum analyze;",
          [],
          timeout: :infinity
        )

      "full" ->
        Logger.info("Running VACUUM FULL.")

        Logger.warn(
          "Re-packing your entire database may take a while and will consume extra disk space during the process."
        )

        Repo.query!(
          "vacuum full;",
          [],
          timeout: :infinity
        )

      _ ->
        Logger.error("Error: invalid vacuum argument.")
    end
  end
end
