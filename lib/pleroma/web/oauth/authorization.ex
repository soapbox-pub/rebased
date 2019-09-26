# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Authorization do
  use Ecto.Schema

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization

  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{}

  schema "oauth_authorizations" do
    field(:token, :string)
    field(:scopes, {:array, :string}, default: [])
    field(:valid_until, :naive_datetime_usec)
    field(:used, :boolean, default: false)
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:app, App)

    timestamps()
  end

  @spec create_authorization(App.t(), User.t() | %{}, [String.t()] | nil) ::
          {:ok, Authorization.t()} | {:error, Changeset.t()}
  def create_authorization(%App{} = app, %User{} = user, scopes \\ nil) do
    %{
      scopes: scopes || app.scopes,
      user_id: user.id,
      app_id: app.id
    }
    |> create_changeset()
    |> Repo.insert()
  end

  @spec create_changeset(map()) :: Changeset.t()
  def create_changeset(attrs \\ %{}) do
    %Authorization{}
    |> cast(attrs, [:user_id, :app_id, :scopes, :valid_until])
    |> validate_required([:app_id, :scopes])
    |> add_token()
    |> add_lifetime()
  end

  defp add_token(changeset) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    put_change(changeset, :token, token)
  end

  defp add_lifetime(changeset) do
    put_change(changeset, :valid_until, NaiveDateTime.add(NaiveDateTime.utc_now(), 60 * 10))
  end

  @spec use_changeset(Authtorizatiton.t(), map()) :: Changeset.t()
  def use_changeset(%Authorization{} = auth, params) do
    auth
    |> cast(params, [:used])
    |> validate_required([:used])
  end

  @spec use_token(Authorization.t()) ::
          {:ok, Authorization.t()} | {:error, Changeset.t()} | {:error, String.t()}
  def use_token(%Authorization{used: false, valid_until: valid_until} = auth) do
    if NaiveDateTime.diff(NaiveDateTime.utc_now(), valid_until) < 0 do
      Repo.update(use_changeset(auth, %{used: true}))
    else
      {:error, "token expired"}
    end
  end

  def use_token(%Authorization{used: true}), do: {:error, "already used"}

  @spec delete_user_authorizations(User.t()) :: {integer(), any()}
  def delete_user_authorizations(%User{} = user) do
    user
    |> delete_by_user_query
    |> Repo.delete_all()
  end

  def delete_by_user_query(%User{id: user_id}) do
    from(a in __MODULE__, where: a.user_id == ^user_id)
  end

  @doc "gets auth for app by token"
  @spec get_by_token(App.t(), String.t()) :: {:ok, t()} | {:error, :not_found}
  def get_by_token(%App{id: app_id} = _app, token) do
    from(t in __MODULE__, where: t.app_id == ^app_id and t.token == ^token)
    |> Repo.find_resource()
  end
end
