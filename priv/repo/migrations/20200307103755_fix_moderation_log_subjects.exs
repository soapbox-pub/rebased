defmodule Pleroma.Repo.Migrations.FixModerationLogSubjects do
  use Ecto.Migration

  def change do
    execute(
      "update moderation_log set data = safe_jsonb_set(data, '{subject}', safe_jsonb_set('[]'::jsonb, '{0}', data->'subject')) where jsonb_typeof(data->'subject') != 'array' and data->>'action' = ANY('{revoke,grant,activate,deactivate,delete}');"
    )
  end
end
