defmodule Pleroma.Web.EmailView do
  use Pleroma.Web, :view
  import Phoenix.HTML
  import Phoenix.HTML.Link

  def avatar_url(user) do
    Pleroma.User.avatar_url(user)
  end

  def format_date(date) when is_binary(date) do
    date
    |> Timex.parse!("{ISO:Extended:Z}")
    |> Timex.format!("{Mshort} {D}, {YYYY} {h24}:{m}")
  end

  def admin_user_url(%{id: id}) do
    Pleroma.Web.Endpoint.url() <> "/pleroma/admin/#/users/" <> id
  end
end
