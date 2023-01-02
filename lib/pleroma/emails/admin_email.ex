# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.AdminEmail do
  @moduledoc "Admin emails"

  import Swoosh.Email

  alias Pleroma.Config
  alias Pleroma.HTML
  alias Pleroma.Web.Router.Helpers

  defp instance_config, do: Config.get(:instance)
  defp instance_name, do: instance_config()[:name]

  defp instance_notify_email do
    Keyword.get(instance_config(), :notify_email, instance_config()[:email])
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

            %{"id" => id} when is_binary(id) ->
              "<li><a href=\"#{id}\">#{id}</li>"

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
    <p>Reported by: <a href="#{reporter.ap_id}">#{reporter.nickname}</a></p>
    <p>Reported Account: <a href="#{account.ap_id}">#{account.nickname}</a></p>
    #{comment_html}
    #{statuses_html}
    <p>
    <a href="#{Pleroma.Web.Endpoint.url()}/pleroma/admin/#/reports/index">View Reports in AdminFE</a>
    """

    new()
    |> to({to.name, to.email})
    |> from({instance_name(), instance_notify_email()})
    |> subject("#{instance_name()} Report")
    |> html_body(html_body)
  end

  def new_unapproved_registration(to, account) do
    html_body = """
    <p>New account for review: <a href="#{account.ap_id}">@#{account.nickname}</a></p>
    <blockquote>#{HTML.strip_tags(account.registration_reason)}</blockquote>
    <a href="#{Pleroma.Web.Endpoint.url()}/pleroma/admin/#/users/#{account.id}/">Visit AdminFE</a>
    """

    new()
    |> to({to.name, to.email})
    |> from({instance_name(), instance_notify_email()})
    |> subject("New account up for review on #{instance_name()} (@#{account.nickname})")
    |> html_body(html_body)
  end
end
