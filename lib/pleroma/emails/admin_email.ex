# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.AdminEmail do
  @moduledoc "Admin emails"

  import Swoosh.Email

  alias Pleroma.Config
  alias Pleroma.Web.Router.Helpers

  defp instance_config, do: Pleroma.Config.get(:instance)
  defp instance_name, do: instance_config()[:name]

  defp instance_notify_email do
    Keyword.get(instance_config(), :notify_email, instance_config()[:email])
  end

  defp user_url(user) do
    Helpers.user_feed_url(Pleroma.Web.Endpoint, :feed_redirect, user.id)
  end

  def test_email(mail_to \\ nil) do
    html_body = """
    <h3>Instance Test Email</h3>
    <p>A test email was requested. Hello. :)</p>
    """

    new()
    |> to(mail_to || Config.get([:instance, :email]))
    |> from({instance_name(), instance_notify_email()})
    |> subject("Instance Test Email")
    |> html_body(html_body)
  end

  def report(to, reporter, account, statuses, comment) do
    comment_html =
      if comment do
        "<p>Comment: #{comment}"
      else
        ""
      end

    statuses_html =
      if is_list(statuses) && length(statuses) > 0 do
        statuses_list_html =
          statuses
          |> Enum.map(fn
            %{id: id} ->
              status_url = Helpers.o_status_url(Pleroma.Web.Endpoint, :notice, id)
              "<li><a href=\"#{status_url}\">#{status_url}</li>"

            id when is_binary(id) ->
              "<li><a href=\"#{id}\">#{id}</li>"
          end)
          |> Enum.join("\n")

        """
        <p> Statuses:
          <ul>
            #{statuses_list_html}
          </ul>
        </p>
        """
      else
        ""
      end

    html_body = """
    <p>Reported by: <a href="#{user_url(reporter)}">#{reporter.nickname}</a></p>
    <p>Reported Account: <a href="#{user_url(account)}">#{account.nickname}</a></p>
    #{comment_html}
    #{statuses_html}
    """

    new()
    |> to({to.name, to.email})
    |> from({instance_name(), instance_notify_email()})
    |> subject("#{instance_name()} Report")
    |> html_body(html_body)
  end
end
