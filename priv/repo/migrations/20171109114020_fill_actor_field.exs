defmodule Pleroma.Repo.Migrations.FillActorField do
  use Ecto.Migration

  alias Pleroma.{Repo, Activity}

  def up do
    max = Repo.aggregate(Activity, :max, :id)
    IO.puts("#{max} activities")
    chunks = 0..(round(max / 10_000))

    Enum.each(chunks, fn (i) ->
      min = i * 10_000
      max = min + 10_000
      IO.puts("Updating #{min}")
      execute("""
        update activities set actor = data->>'actor' where id > #{min} and id <= #{max};
      """)
      |> IO.inspect
    end)
  end

  def down do
  end
end

