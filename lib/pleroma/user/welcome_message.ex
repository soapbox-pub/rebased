# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.WelcomeMessage do
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  def post_welcome_message_to_user(user) do
    with %User{} = sender_user <- welcome_user(),
         message when is_binary(message) <- welcome_message() do
      CommonAPI.post(sender_user, %{
        "visibility" => "direct",
        "status" => "@#{user.nickname}\n#{message}"
      })
    else
      _ -> {:ok, nil}
    end
  end

  defp welcome_user do
    with nickname when is_binary(nickname) <-
           Pleroma.Config.get([:instance, :welcome_user_nickname]),
         %User{local: true} = user <- User.get_cached_by_nickname(nickname) do
      user
    else
      _ -> nil
    end
  end

  defp welcome_message do
    Pleroma.Config.get([:instance, :welcome_message])
  end
end
