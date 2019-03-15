# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token do
  use Ecto.Schema

  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token

  schema "oauth_tokens" do
    field(:token, :string)
    field(:refresh_token, :string)
    field(:scopes, {:array, :string}, default: [])
    field(:valid_until, :naive_datetime)
    belongs_to(:user, Pleroma.User, type: Pleroma.FlakeId)
    belongs_to(:app, App)

    timestamps()
  end

  def exchange_token(app, auth) do
    with {:ok, auth} <- Authorization.use_token(auth),
         true <- auth.app_id == app.id do
      create_token(app, Repo.get(User, auth.user_id), auth.scopes)
    end
  end

  def create_token(%App{} = app, %User{} = user, scopes \\ nil) do
    scopes = scopes || app.scopes
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    refresh_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    token = %Token{
      token: token,
      refresh_token: refresh_token,
      scopes: scopes,
      user_id: user.id,
      app_id: app.id,
      valid_until: NaiveDateTime.add(NaiveDateTime.utc_now(), 60 * 10)
    }

    Repo.insert(token)
  end

  def delete_user_tokens(%User{id: user_id}) do
    from(
      t in Token,
      where: t.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  def delete_user_token(%User{id: user_id}, token_id) do
    from(
      t in Token,
      where: t.user_id == ^user_id,
      where: t.id == ^token_id
    )
    |> Repo.delete_all()
  end

  def get_user_tokens(%User{id: user_id}) do
    from(
      t in Token,
      where: t.user_id == ^user_id
    )
    |> Repo.all()
    |> Repo.preload(:app)
  end
end
