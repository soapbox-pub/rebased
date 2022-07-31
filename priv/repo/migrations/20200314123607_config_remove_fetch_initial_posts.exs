# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ConfigRemoveFetchInitialPosts do
  use Ecto.Migration

  def change do
    execute(
      "delete from config where config.key = ':fetch_initial_posts' and config.group = ':pleroma';",
      ""
    )
  end
end
