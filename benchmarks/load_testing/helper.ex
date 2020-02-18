defmodule Pleroma.LoadTesting.Helper do
  alias Ecto.Adapters.SQL
  alias Pleroma.Repo

  def to_sec(microseconds), do: microseconds / 1_000_000

  def clean_tables do
    IO.puts("Deleting old data...\n")
    SQL.query!(Repo, "TRUNCATE users CASCADE;")
    SQL.query!(Repo, "TRUNCATE activities CASCADE;")
    SQL.query!(Repo, "TRUNCATE objects CASCADE;")
    SQL.query!(Repo, "TRUNCATE oban_jobs CASCADE;")
  end
end
