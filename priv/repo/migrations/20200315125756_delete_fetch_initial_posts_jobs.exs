defmodule Pleroma.Repo.Migrations.DeleteFetchInitialPostsJobs do
  use Ecto.Migration

  def change do
    execute(
      "delete from oban_jobs where worker = 'Pleroma.Workers.BackgroundWorker' and args->>'op' = 'fetch_initial_posts';",
      ""
    )
  end
end
