defmodule Pleroma.Repo.Migrations.AddNewsletterFieldToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:accepts_newsletter, :boolean, default: false)
    end
  end
end
