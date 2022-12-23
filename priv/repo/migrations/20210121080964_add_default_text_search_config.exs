# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddDefaultTextSearchConfig do
  use Ecto.Migration

  def change do
    execute("DO $$
    BEGIN
    execute 'ALTER DATABASE \"'||current_database()||'\" SET default_text_search_config = ''english'' ';
    END
    $$;")
  end
end
