defmodule Pleroma.Repo.Migrations.RemoveEmbededObjects do
  use Ecto.Migration

  # TODO: bench on a real DB and add clippy if it takes too long
  def change do
  execute """
  update activities set data = jsonb_set(data, '{object}'::text[], data->'object'->'id') where data->>'type' = 'Create' and data->'object'->>'id' is not null;
  """
  end
end
