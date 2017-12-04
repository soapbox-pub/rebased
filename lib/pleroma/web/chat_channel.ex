defmodule Pleroma.Web.ChatChannel do
  use Phoenix.Channel

  def join("chat:public", _message, socket) do
    {:ok, socket}
  end

  def handle_in("new_msg", %{"text" => text}, socket) do
    author = socket.assigns[:user]
    author = Pleroma.Web.MastodonAPI.AccountView.render("account.json", user: author)
    broadcast! socket, "new_msg", %{text: text, author: author}
    {:noreply, socket}
  end
end
