# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.UserSocket do
  use Phoenix.Socket
  alias Pleroma.User

  ## Channels
  # channel "room:*", Pleroma.Web.RoomChannel
  channel("chat:*", Pleroma.Web.ChatChannel)

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(%{"token" => token}, socket) do
    with true <- Pleroma.Config.get([:chat, :enabled]),
         {:ok, user_id} <- Phoenix.Token.verify(socket, "user socket", token, max_age: 84_600),
         %User{} = user <- Pleroma.User.get_cached_by_id(user_id) do
      {:ok, assign(socket, :user_name, user.nickname)}
    else
      _e -> :error
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Pleroma.Web.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil
end
