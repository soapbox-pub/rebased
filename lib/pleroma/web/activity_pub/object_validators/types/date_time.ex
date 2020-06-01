defmodule Pleroma.Web.ActivityPub.ObjectValidators.Types.DateTime do
  @moduledoc """
  The AP standard defines the date fields in AP as xsd:DateTime. Elixir's
  DateTime can't parse this, but it can parse the related iso8601. This
  module punches the date until it looks like iso8601 and normalizes to
  it.

  DateTimes without a timezone offset are treated as UTC.

  Reference: https://www.w3.org/TR/activitystreams-vocabulary/#dfn-published
  """
  use Ecto.Type

  def type, do: :string

  def cast(datetime) when is_binary(datetime) do
    with {:ok, datetime, _} <- DateTime.from_iso8601(datetime) do
      {:ok, DateTime.to_iso8601(datetime)}
    else
      {:error, :missing_offset} -> cast("#{datetime}Z")
      _e -> :error
    end
  end

  def cast(_), do: :error

  def dump(data) do
    {:ok, data}
  end

  def load(data) do
    {:ok, data}
  end
end
