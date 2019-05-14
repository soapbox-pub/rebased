# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.App do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "apps" do
    field(:client_name, :string)
    field(:redirect_uris, :string)
    field(:scopes, {:array, :string}, default: [])
    field(:website, :string)
    field(:client_id, :string)
    field(:client_secret, :string)

    timestamps()
  end

  def register_changeset(struct, params \\ %{}) do
    changeset =
      struct
      |> cast(params, [:client_name, :redirect_uris, :scopes, :website])
      |> validate_required([:client_name, :redirect_uris, :scopes])

    if changeset.valid? do
      changeset
      |> put_change(
        :client_id,
        :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      )
      |> put_change(
        :client_secret,
        :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      )
    else
      changeset
    end
  end
end
