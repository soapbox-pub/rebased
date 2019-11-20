defmodule Pleroma.Repo.Migrations.DataMigrationPopulateUserRelationships do
  use Ecto.Migration

  alias Ecto.Adapters.SQL
  alias Pleroma.Repo

  require Logger

  def up do
    Enum.each(
      [blocks: 1, mutes: 2, muted_reblogs: 3, muted_notifications: 4, subscribers: 5],
      fn {field, relationship_type_code} ->
        migrate(field, relationship_type_code)

        if field == :subscribers do
          drop_if_exists(index(:users, [:subscribers]))
        end
      end
    )
  end

  def down, do: :noop

  defp migrate(field, relationship_type_code) do
    Logger.info("Processing users.#{field}...")

    {:ok, %{rows: field_rows}} =
      SQL.query(Repo, "SELECT id, #{field} FROM users WHERE #{field} != '{}'")

    target_ap_ids =
      Enum.flat_map(
        field_rows,
        fn [_, ap_ids] -> ap_ids end
      )
      |> Enum.uniq()

    # Selecting ids of all targets at once in order to reduce the number of SELECT queries
    {:ok, %{rows: target_ap_id_id}} =
      SQL.query(Repo, "SELECT ap_id, id FROM users WHERE ap_id = ANY($1)", [target_ap_ids])

    target_id_by_ap_id = Enum.into(target_ap_id_id, %{}, fn [k, v] -> {k, v} end)

    Enum.each(
      field_rows,
      fn [source_id, target_ap_ids] ->
        source_uuid = Ecto.UUID.cast!(source_id)

        for target_ap_id <- target_ap_ids do
          target_id = target_id_by_ap_id[target_ap_id]

          with {:ok, target_uuid} <- target_id && Ecto.UUID.cast(target_id) do
            execute("""
            INSERT INTO user_relationships(
              source_id, target_id, relationship_type, inserted_at
            )
            VALUES(
              '#{source_uuid}'::uuid, '#{target_uuid}'::uuid, #{relationship_type_code}, now()
            )
            ON CONFLICT (source_id, relationship_type, target_id) DO NOTHING
            """)
          else
            _ -> Logger.warn("Unresolved #{field} reference: (#{source_uuid}, #{target_id})")
          end
        end
      end
    )
  end
end
