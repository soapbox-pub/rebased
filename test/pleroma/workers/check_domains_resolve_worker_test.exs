# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.CheckDomainsResolveWorkerTest do
  use Pleroma.DataCase

  alias Pleroma.Domain
  alias Pleroma.Workers.CheckDomainResolveWorker

  setup do
    Pleroma.Web.Endpoint.config_change(
      [{Pleroma.Web.Endpoint, url: [host: "pleroma.example.org", scheme: "https", port: 443]}],
      []
    )

    clear_config([Pleroma.Web.Endpoint, :url, :host], "pleroma.example.org")

    Tesla.Mock.mock_global(fn
      %{url: "https://pleroma.example.org/.well-known/host-meta"} ->
        %Tesla.Env{
          status: 200,
          body:
            "test/fixtures/webfinger/pleroma-host-meta.xml"
            |> File.read!()
            |> String.replace("{{domain}}", "pleroma.example.org")
        }

      %{url: "https://example.org/.well-known/host-meta"} ->
        %Tesla.Env{
          status: 200,
          body:
            "test/fixtures/webfinger/pleroma-host-meta.xml"
            |> File.read!()
            |> String.replace("{{domain}}", "pleroma.example.org")
        }

      %{url: "https://social.example.org/.well-known/host-meta"} ->
        %Tesla.Env{
          status: 302,
          headers: [{"location", "https://pleroma.example.org/.well-known/host-meta"}]
        }

      %{url: "https://notpleroma.example.org/.well-known/host-meta"} ->
        %Tesla.Env{
          status: 200,
          body:
            "test/fixtures/webfinger/pleroma-host-meta.xml"
            |> File.read!()
            |> String.replace("{{domain}}", "notpleroma.example.org")
        }

      %{url: "https://wrong.example.org/.well-known/host-meta"} ->
        %Tesla.Env{
          status: 302,
          headers: [{"location", "https://notpleroma.example.org/.well-known/host-meta"}]
        }

      %{url: "https://bad.example.org/.well-known/host-meta"} ->
        %Tesla.Env{status: 404}
    end)

    on_exit(fn ->
      Pleroma.Web.Endpoint.config_change(
        [{Pleroma.Web.Endpoint, url: [host: "localhost"]}],
        []
      )
    end)
  end

  test "verifies domain state" do
    {:ok, %{id: domain_id}} =
      Domain.create(%{
        domain: "example.org"
      })

    {:ok, domain} = CheckDomainResolveWorker.perform(%Oban.Job{args: %{"id" => domain_id}})

    assert domain.resolves == true
    assert domain.last_checked_at != nil
  end

  test "verifies domain state for a redirect" do
    {:ok, %{id: domain_id}} =
      Domain.create(%{
        domain: "social.example.org"
      })

    {:ok, domain} = CheckDomainResolveWorker.perform(%Oban.Job{args: %{"id" => domain_id}})

    assert domain.resolves == true
    assert domain.last_checked_at != nil
  end

  test "doesn't verify state for an incorrect redirect" do
    {:ok, %{id: domain_id}} =
      Domain.create(%{
        domain: "wrong.example.org"
      })

    {:ok, domain} = CheckDomainResolveWorker.perform(%Oban.Job{args: %{"id" => domain_id}})

    assert domain.resolves == false
    assert domain.last_checked_at != nil
  end

  test "doesn't verify state for unimplemented redirect" do
    {:ok, %{id: domain_id}} =
      Domain.create(%{
        domain: "bad.example.org"
      })

    {:ok, domain} = CheckDomainResolveWorker.perform(%Oban.Job{args: %{"id" => domain_id}})

    assert domain.resolves == false
    assert domain.last_checked_at != nil
  end
end
