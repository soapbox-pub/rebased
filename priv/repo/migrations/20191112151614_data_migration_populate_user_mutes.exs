defmodule Pleroma.Repo.Migrations.DataMigrationPopulateUserMutes do
  use Ecto.Migration

  alias Ecto.Adapters.SQL
  alias Pleroma.Repo

  require Logger

  def up do
    {:ok, %{rows: mute_rows}} = SQL.query(Repo, "SELECT id, mutes FROM users WHERE mutes != '{}'")

    mutee_ap_ids =
      Enum.flat_map(
        mute_rows,
        fn [_, ap_ids] -> ap_ids end
      )
      |> Enum.uniq()

    # Selecting ids of all mutees at once in order to reduce the number of SELECT queries
    {:ok, %{rows: mutee_ap_id_id}} =
      SQL.query(Repo, "SELECT ap_id, id FROM users WHERE ap_id = ANY($1)", [mutee_ap_ids])

    mutee_id_by_ap_id = Enum.into(mutee_ap_id_id, %{}, fn [k, v] -> {k, v} end)

    Enum.each(
      mute_rows,
      fn [muter_id, mutee_ap_ids] ->
        muter_uuid = Ecto.UUID.cast!(muter_id)

        for mutee_ap_id <- mutee_ap_ids do
          mutee_id = mutee_id_by_ap_id[mutee_ap_id]

          with {:ok, mutee_uuid} <- mutee_id && Ecto.UUID.cast(mutee_id) do
            execute(
              "INSERT INTO user_mutes(muter_id, mutee_id, inserted_at) " <>
                "VALUES('#{muter_uuid}'::uuid, '#{mutee_uuid}'::uuid, now()) " <>
                "ON CONFLICT (muter_id, mutee_id) DO NOTHING"
            )
          else
            _ -> Logger.warn("Missing reference: (#{muter_uuid}, #{mutee_id})")
          end
        end
      end
    )
  end

  def down, do: :noop
end
