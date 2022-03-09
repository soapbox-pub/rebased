# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.FixModerationLogSubjects do
  use Ecto.Migration

  def change do
    execute(
      "update moderation_log set data = safe_jsonb_set(data, '{subject}', safe_jsonb_set('[]'::jsonb, '{0}', data->'subject')) where jsonb_typeof(data->'subject') != 'array' and data->>'action' = ANY('{revoke,grant,activate,deactivate,delete}');"
    )
  end
end
