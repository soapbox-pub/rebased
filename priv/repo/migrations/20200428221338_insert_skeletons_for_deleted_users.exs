defmodule Pleroma.Repo.Migrations.InsertSkeletonsForDeletedUsers do
  use Ecto.Migration

  alias Pleroma.User
  alias Pleroma.Repo

  import Ecto.Query

  def change do
    Application.ensure_all_started(:flake_id)

    local_ap_id =
      User.Query.build(%{local: true})
      |> select([u], u.ap_id)
      |> limit(1)
      |> Repo.one()

    unless local_ap_id == nil do
      # Hack to get instance base url because getting it from Phoenix
      # would require starting the whole application
      instance_uri =
        local_ap_id
        |> URI.parse()
        |> Map.put(:query, nil)
        |> Map.put(:path, nil)
        |> URI.to_string()

      {:ok, %{rows: ap_ids}} =
        Ecto.Adapters.SQL.query(
          Repo,
          "select distinct unnest(nonexistent_locals.recipients) from activities, lateral (select array_agg(recipient) as recipients from unnest(activities.recipients) as recipient where recipient similar to '#{instance_uri}/users/[A-Za-z0-9]*' and not(recipient in (select ap_id from users))) nonexistent_locals;",
          [],
          timeout: :infinity
        )

      ap_ids
      |> Enum.each(fn [ap_id] ->
        Ecto.Changeset.change(%User{}, deactivated: true, ap_id: ap_id)
        |> Repo.insert()
      end)
    end
  end
end
