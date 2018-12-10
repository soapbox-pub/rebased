defmodule Pleroma.Web.OEmbed do
  alias Pleroma.{Repo, Object, Activity, User}
  alias Pleroma.Formatter

  def recognize_path(url) do
    details = Regex.named_captures(~r/.+\/(?<route>.+)\/(?<id>\w+).*$/, url)

    case details do
      %{ "route" => "notice", "id" => id } ->
                                    %{type: :activity, entity: Repo.get(Activity, id) }
      %{ "route" => "users", "id" => nickname } ->
                                    %{type: :user, entity: User.get_by_nickname(nickname) }
      _ ->
        { :error, "no matching route"}
    end
  end

  def truncated_content(activity) do
    content = activity.data['object']['content']
    IO.puts(content)
    Formatter.truncate(content)
  end
end
