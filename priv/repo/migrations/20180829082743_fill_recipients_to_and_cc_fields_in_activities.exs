defmodule Pleroma.Repo.Migrations.FillRecipientsToAndCcFieldsInActivities do
  use Ecto.Migration
  alias Pleroma.{Repo, Activity}

  def up do
    max = Repo.aggregate(Activity, :max, :id)
    if max do
      IO.puts("#{max} activities")
      chunks = 0..(round(max / 10_000))

      Enum.each(chunks, fn (i) ->
        min = i * 10_000
        max = min + 10_000
        execute("""
        update activities set recipients_to = array(select jsonb_array_elements_text(data->'to')) where id > #{min} and id <= #{max} and jsonb_typeof(data->'to') = 'array';
        """)
        |> IO.inspect
        execute("""
        update activities set recipients_cc = array(select jsonb_array_elements_text(data->'cc')) where id > #{min} and id <= #{max} and jsonb_typeof(data->'cc') = 'array';
        """)
        |> IO.inspect
      end)
    end
  end
end
