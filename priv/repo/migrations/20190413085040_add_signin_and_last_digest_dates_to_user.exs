defmodule Pleroma.Repo.Migrations.AddSigninAndLastDigestDatesToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:last_digest_emailed_at, :naive_datetime, default: fragment("now()"))
    end
  end
end
