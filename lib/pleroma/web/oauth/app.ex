defmodule Pleroma.Web.OAuth.App do
  use Ecto.Schema
  import Ecto.{Changeset}

  schema "apps" do
    field :client_name, :string
    field :redirect_uris, :string
    field :scopes, :string
    field :website, :string
    field :client_id, :string
    field :client_secret, :string

    timestamps()
  end

  def register_changeset(struct, params \\ %{}) do
    changeset = struct
    |> cast(params, [:client_name, :redirect_uris, :scopes, :website])
    |> validate_required([:client_name, :redirect_uris, :scopes])

    if changeset.valid? do
      changeset
      |> put_change(:client_id, :crypto.strong_rand_bytes(32) |> Base.url_encode64)
      |> put_change(:client_secret, :crypto.strong_rand_bytes(32) |> Base.url_encode64)
    else
      changeset
    end
  end
end
