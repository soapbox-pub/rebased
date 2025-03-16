defmodule Pleroma.Web.ActivityPub.MRF.RemoteReportPolicy do
  @moduledoc "Drop remote reports if they don't contain enough information."
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.Config

  @impl true
  def filter(%{"type" => "Flag"} = object) do
    with {_, false} <- {:local, local?(object)},
         {:ok, _} <- maybe_reject_all(object),
         {:ok, _} <- maybe_reject_anonymous(object),
         {:ok, _} <- maybe_reject_third_party(object),
         {:ok, _} <- maybe_reject_empty_message(object) do
      {:ok, object}
    else
      {:local, true} -> {:ok, object}
      {:reject, message} -> {:reject, message}
      error -> {:reject, error}
    end
  end

  def filter(object), do: {:ok, object}

  defp maybe_reject_all(object) do
    if Config.get([:mrf_remote_report, :reject_all]) do
      {:reject, "[RemoteReportPolicy] Remote report"}
    else
      {:ok, object}
    end
  end

  defp maybe_reject_anonymous(%{"actor" => actor} = object) do
    with true <- Config.get([:mrf_remote_report, :reject_anonymous]),
         %URI{path: "/actor"} <- URI.parse(actor) do
      {:reject, "[RemoteReportPolicy] Anonymous: #{actor}"}
    else
      _ -> {:ok, object}
    end
  end

  defp maybe_reject_third_party(%{"object" => objects} = object) do
    {_, to} =
      case objects do
        [head | tail] when is_binary(head) -> {tail, head}
        s when is_binary(s) -> {[], s}
        _ -> {[], ""}
      end

    with true <- Config.get([:mrf_remote_report, :reject_third_party]),
         false <- String.starts_with?(to, Pleroma.Web.Endpoint.url()) do
      {:reject, "[RemoteReportPolicy] Third-party: #{to}"}
    else
      _ -> {:ok, object}
    end
  end

  defp maybe_reject_empty_message(%{"content" => content} = object)
       when is_binary(content) and content != "" do
    {:ok, object}
  end

  defp maybe_reject_empty_message(object) do
    if Config.get([:mrf_remote_report, :reject_empty_message]) do
      {:reject, ["RemoteReportPolicy] No content"]}
    else
      {:ok, object}
    end
  end

  defp local?(%{"actor" => actor}) do
    String.starts_with?(actor, Pleroma.Web.Endpoint.url())
  end

  @impl true
  def describe do
    mrf_remote_report =
      Config.get(:mrf_remote_report)
      |> Enum.into(%{})

    {:ok, %{mrf_remote_report: mrf_remote_report}}
  end

  @impl true
  def config_description do
    %{
      key: :mrf_remote_report,
      related_policy: "Pleroma.Web.ActivityPub.MRF.RemoteReportPolicy",
      label: "MRF Remote Report",
      description: "Drop remote reports if they don't contain enough information.",
      children: [
        %{
          key: :reject_all,
          type: :boolean,
          description: "Reject all remote reports? (this option takes precedence)",
          suggestions: [false]
        },
        %{
          key: :reject_anonymous,
          type: :boolean,
          description: "Reject anonymous remote reports?",
          suggestions: [true]
        },
        %{
          key: :reject_third_party,
          type: :boolean,
          description: "Reject reports on users from third-party instances?",
          suggestions: [true]
        },
        %{
          key: :reject_empty_message,
          type: :boolean,
          description: "Reject remote reports with no message?",
          suggestions: [true]
        }
      ]
    }
  end
end
