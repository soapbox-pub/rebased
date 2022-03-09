# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DeleteFetchInitialPostsJobs do
  use Ecto.Migration

  def change do
    execute(
      "delete from oban_jobs where worker = 'Pleroma.Workers.BackgroundWorker' and args->>'op' = 'fetch_initial_posts';",
      ""
    )
  end
end
