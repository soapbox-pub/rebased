# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.WelcomeMessage do
  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  @spec enabled?() :: boolean()
  def enabled?, do: Config.get([:welcome, :direct_message, :enabled], false)

  @spec post_message(User.t()) :: {:ok, Pleroma.Activity.t() | nil}
  def post_message(user) do
    [:welcome, :direct_message, :sender_nickname]
    |> Config.get(nil)
    |> fetch_sender()
    |> do_post(user, welcome_message())
  end

  defp do_post(%User{} = sender, %User{nickname: nickname}, message)
       when is_binary(message) do
    CommonAPI.post(
      sender,
      %{
        visibility: "direct",
        status: "@#{nickname}\n#{message}"
      }
    )
  end

  defp do_post(_sender, _recipient, _message), do: {:ok, nil}

  defp fetch_sender(nickname) when is_binary(nickname) do
    with %User{local: true} = user <- User.get_cached_by_nickname(nickname) do
      user
    else
      _ -> nil
    end
  end

  defp fetch_sender(_), do: nil

  defp welcome_message do
    Config.get([:welcome, :direct_message, :message], nil)
  end
end
