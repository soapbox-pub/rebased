# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.EmailList do
  @moduledoc """
  Functions for generating email lists from local users.
  """
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User

  @header_row ["Email Address", "Nickname", "Subscribe?"]

  defp query(:subscribers) do
    User.Query.build(%{
      local: true,
      active: true,
      accepts_email_list: true
    })
    |> where([u], not is_nil(u.email))
  end

  defp query(:unsubscribers) do
    User.Query.build(%{
      local: true,
      accepts_email_list: false
    })
    |> where([u], not is_nil(u.email))
  end

  def generate_csv(audience) when is_atom(audience) do
    audience
    |> query()
    |> generate_csv()
  end

  def generate_csv(%Ecto.Query{} = query) do
    query
    |> Repo.all()
    |> Enum.map(&build_row/1)
    |> build_csv()
  end

  defp build_row(%User{} = user) do
    [
      user.email,
      user.nickname,
      user.accepts_email_list
    ]
  end

  defp build_csv(lines) do
    [@header_row | lines]
    |> CSV.encode()
    |> Enum.join()
  end
end
