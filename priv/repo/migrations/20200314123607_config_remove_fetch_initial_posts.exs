defmodule Pleroma.Repo.Migrations.ConfigRemoveFetchInitialPosts do
  use Ecto.Migration

  def change do
    execute(
      "delete from config where config.key = ':fetch_initial_posts' and config.group = ':pleroma';",
      ""
    )
  end
end
