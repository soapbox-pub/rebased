defmodule Pleroma.Repo.Migrations.FillRecipientsInActivities do
  use Ecto.Migration
  alias Pleroma.{Repo, Activity}

  def up do
    max = Repo.aggregate(Activity, :max, :id)

    if max do
      IO.puts("#{max} activities")
      chunks = 0..round(max / 10_000)

      Enum.each(chunks, fn i ->
        min = i * 10_000
        max = min + 10_000

        execute("""
        update activities set recipients = array(select jsonb_array_elements_text(data->'to')) where id > #{
          min
        } and id <= #{max};
        """)
        |> IO.inspect()
      end)
    end
  end

  def down, do: :ok
end
