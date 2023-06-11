defmodule Pleroma.Repo.Migrations.DropUnusedIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    drop_if_exists(
      index(:activities, ["(data->>'actor')", "inserted_at desc"], name: :activities_actor_index)
    )

    drop_if_exists(index(:activities, ["(data->'to')"], name: :activities_to_index))

    drop_if_exists(index(:activities, ["(data->'cc')"], name: :activities_cc_index))

    drop_if_exists(index(:activities, ["(split_part(actor, '/', 3))"], name: :activities_hosts))

    drop_if_exists(
      index(:activities, ["(data->'object'->>'inReplyTo')"], name: :activities_in_reply_to)
    )

    drop_if_exists(
      index(:activities, ["((data #> '{\"object\",\"likes\"}'))"], name: :activities_likes)
    )
  end

  def down do
    create_if_not_exists(
      index(:activities, ["(data->>'actor')", "inserted_at desc"],
        name: :activities_actor_index,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:activities, ["(data->'to')"],
        name: :activities_to_index,
        using: :gin,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:activities, ["(data->'cc')"],
        name: :activities_cc_index,
        using: :gin,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:activities, ["(split_part(actor, '/', 3))"],
        name: :activities_hosts,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:activities, ["(data->'object'->>'inReplyTo')"],
        name: :activities_in_reply_to,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:activities, ["((data #> '{\"object\",\"likes\"}'))"],
        name: :activities_likes,
        using: :gin,
        concurrently: true
      )
    )
  end
end
