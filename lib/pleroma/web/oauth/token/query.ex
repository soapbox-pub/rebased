# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token.Query do
  @moduledoc """
  Contains queries for OAuth Token.
  """

  import Ecto.Query, only: [from: 2]

  @type query :: Ecto.Queryable.t() | Token.t()

  alias Pleroma.Web.OAuth.Token

  @spec get_by_refresh_token(query, String.t()) :: query
  def get_by_refresh_token(query \\ Token, refresh_token) do
    from(q in query, where: q.refresh_token == ^refresh_token)
  end

  @spec get_by_token(query, String.t()) :: query
  def get_by_token(query \\ Token, token) do
    from(q in query, where: q.token == ^token)
  end

  @spec get_by_app(query, String.t()) :: query
  def get_by_app(query \\ Token, app_id) do
    from(q in query, where: q.app_id == ^app_id)
  end

  @spec get_by_id(query, String.t()) :: query
  def get_by_id(query \\ Token, id) do
    from(q in query, where: q.id == ^id)
  end

  @spec get_expired_tokens(query, DateTime.t() | nil) :: query
  def get_expired_tokens(query \\ Token, date \\ nil) do
    expired_date = date || Timex.now()
    from(q in query, where: fragment("?", q.valid_until) < ^expired_date)
  end

  @spec get_by_user(query, String.t()) :: query
  def get_by_user(query \\ Token, user_id) do
    from(q in query, where: q.user_id == ^user_id)
  end

  @spec preload(query, any) :: query
  def preload(query \\ Token, assoc_preload \\ [])

  def preload(query, assoc_preload) when is_list(assoc_preload) do
    from(q in query, preload: ^assoc_preload)
  end

  def preload(query, _assoc_preload), do: query
end
