defmodule Pleroma.Repo.Migrations.DataMigrationPopulateUserBlocks do
  use Ecto.Migration

  alias Ecto.Adapters.SQL
  alias Pleroma.Repo

  require Logger

  def up do
    {:ok, %{rows: block_rows}} =
      SQL.query(Repo, "SELECT id, blocks FROM users WHERE blocks != '{}'")

    blockee_ap_ids =
      Enum.flat_map(
        block_rows,
        fn [_, ap_ids] -> ap_ids end
      )
      |> Enum.uniq()

    # Selecting ids of all blockees at once in order to reduce the number of SELECT queries
    {:ok, %{rows: blockee_ap_id_id}} =
      SQL.query(Repo, "SELECT ap_id, id FROM users WHERE ap_id = ANY($1)", [blockee_ap_ids])

    blockee_id_by_ap_id = Enum.into(blockee_ap_id_id, %{}, fn [k, v] -> {k, v} end)

    Enum.each(
      block_rows,
      fn [blocker_id, blockee_ap_ids] ->
        blocker_uuid = Ecto.UUID.cast!(blocker_id)

        for blockee_ap_id <- blockee_ap_ids do
          blockee_id = blockee_id_by_ap_id[blockee_ap_id]
          blockee_uuid = blockee_id && Ecto.UUID.cast!(blockee_id)

          with {:ok, blockee_uuid} <- Ecto.UUID.cast(blockee_id) do
            execute(
              "INSERT INTO user_blocks(blocker_id, blockee_id, inserted_at) " <>
                "VALUES('#{blocker_uuid}'::uuid, '#{blockee_uuid}'::uuid, now()) " <>
                "ON CONFLICT (blocker_id, blockee_id) DO NOTHING"
            )
          else
            _ -> Logger.warn("Missing reference: (#{blocker_uuid}, #{blockee_id})")
          end
        end
      end
    )
  end

  def down, do: :noop
end
