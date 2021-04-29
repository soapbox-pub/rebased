defmodule Pleroma.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up do
    Oban.Migrations.up(version: 2)
  end

  defdelegate down, to: Oban.Migrations
end
