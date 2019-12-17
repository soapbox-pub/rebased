defmodule Mix.Tasks.Pleroma.NotificationSettings do
  @shortdoc "Enable&Disable privacy option for push notifications"
  @moduledoc """
  Example:

  > mix pleroma.notification_settings --privacy-option=false --nickname-users="parallel588"  # set false only for parallel588 user
  > mix pleroma.notification_settings --privacy-option=true # set true for all users

  """

  use Mix.Task
  import Mix.Pleroma
  import Ecto.Query

  def run(args) do
    start_pleroma()

    {options, _, _} =
      OptionParser.parse(
        args,
        strict: [
          privacy_option: :boolean,
          email_users: :string,
          nickname_users: :string
        ]
      )

    privacy_option = Keyword.get(options, :privacy_option)

    if not is_nil(privacy_option) do
      privacy_option
      |> build_query(options)
      |> Pleroma.Repo.update_all([])
    end

    shell_info("Done")
  end

  defp build_query(privacy_option, options) do
    query =
      from(u in Pleroma.User,
        update: [
          set: [
            notification_settings:
              fragment(
                "jsonb_set(notification_settings, '{privacy_option}', ?)",
                ^privacy_option
              )
          ]
        ]
      )

    user_emails =
      options
      |> Keyword.get(:email_users, "")
      |> String.split(",")
      |> Enum.map(&String.trim(&1))
      |> Enum.reject(&(&1 == ""))

    query =
      if length(user_emails) > 0 do
        where(query, [u], u.email in ^user_emails)
      else
        query
      end

    user_nicknames =
      options
      |> Keyword.get(:nickname_users, "")
      |> String.split(",")
      |> Enum.map(&String.trim(&1))
      |> Enum.reject(&(&1 == ""))

    query =
      if length(user_nicknames) > 0 do
        where(query, [u], u.nickname in ^user_nicknames)
      else
        query
      end

    query
  end
end
