# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.App do
  use Ecto.Schema
  import Ecto.Changeset
  alias Pleroma.Repo

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

  @doc """
  Gets app by attrs or create new  with attrs.
  And updates the scopes if need.
  """
  @spec get_or_make(map(), list(String.t())) :: {:ok, App.t()} | {:error, Ecto.Changeset.t()}
  def get_or_make(attrs, scopes) do
    with %__MODULE__{} = app <- Repo.get_by(__MODULE__, attrs) do
      update_scopes(app, scopes)
    else
      _e ->
        %__MODULE__{}
        |> register_changeset(Map.put(attrs, :scopes, scopes))
        |> Repo.insert()
    end
  end

  defp update_scopes(%__MODULE__{} = app, []), do: {:ok, app}
  defp update_scopes(%__MODULE__{scopes: scopes} = app, scopes), do: {:ok, app}

  defp update_scopes(%__MODULE__{} = app, scopes) do
    app
    |> change(%{scopes: scopes})
    |> Repo.update()
  end
end
