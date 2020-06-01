# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.App do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Pleroma.Repo

  @type t :: %__MODULE__{}

  schema "apps" do
    field(:client_name, :string)
    field(:redirect_uris, :string)
    field(:scopes, {:array, :string}, default: [])
    field(:website, :string)
    field(:client_id, :string)
    field(:client_secret, :string)
    field(:trusted, :boolean, default: false)

    has_many(:oauth_authorizations, Pleroma.Web.OAuth.Authorization, on_delete: :delete_all)
    has_many(:oauth_tokens, Pleroma.Web.OAuth.Token, on_delete: :delete_all)

    timestamps()
  end

  @spec changeset(App.t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params) do
    cast(struct, params, [:client_name, :redirect_uris, :scopes, :website, :trusted])
  end

  @spec register_changeset(App.t(), map()) :: Ecto.Changeset.t()
  def register_changeset(struct, params \\ %{}) do
    changeset =
      struct
      |> changeset(params)
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

  @spec create(map()) :: {:ok, App.t()} | {:error, Ecto.Changeset.t()}
  def create(params) do
    with changeset <- __MODULE__.register_changeset(%__MODULE__{}, params) do
      Repo.insert(changeset)
    end
  end

  @spec update(map()) :: {:ok, App.t()} | {:error, Ecto.Changeset.t()}
  def update(params) do
    with %__MODULE__{} = app <- Repo.get(__MODULE__, params["id"]),
         changeset <- changeset(app, params) do
      Repo.update(changeset)
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

  @spec search(map()) :: {:ok, [App.t()], non_neg_integer()}
  def search(params) do
    query = from(a in __MODULE__)

    query =
      if params[:client_name] do
        from(a in query, where: a.client_name == ^params[:client_name])
      else
        query
      end

    query =
      if params[:client_id] do
        from(a in query, where: a.client_id == ^params[:client_id])
      else
        query
      end

    query =
      if Map.has_key?(params, :trusted) do
        from(a in query, where: a.trusted == ^params[:trusted])
      else
        query
      end

    query =
      from(u in query,
        limit: ^params[:page_size],
        offset: ^((params[:page] - 1) * params[:page_size])
      )

    count = Repo.aggregate(__MODULE__, :count, :id)

    {:ok, Repo.all(query), count}
  end

  @spec destroy(pos_integer()) :: {:ok, App.t()} | {:error, Ecto.Changeset.t()}
  def destroy(id) do
    with %__MODULE__{} = app <- Repo.get(__MODULE__, id) do
      Repo.delete(app)
    end
  end

  @spec errors(Ecto.Changeset.t()) :: map()
  def errors(changeset) do
    Enum.reduce(changeset.errors, %{}, fn
      {:client_name, {error, _}}, acc ->
        Map.put(acc, :name, error)

      {key, {error, _}}, acc ->
        Map.put(acc, key, error)
    end)
  end
end
