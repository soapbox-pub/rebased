defmodule Pleroma.Web.ActivityPub.ObjectValidators.Types.ObjectID do
  use Ecto.Type

  def type, do: :string

  def cast(object) when is_binary(object) do
    with %URI{
           scheme: scheme,
           host: host
         }
         when scheme in ["https", "http"] and not is_nil(host) <-
           URI.parse(object) do
      {:ok, object}
    else
      _ ->
        :error
    end
  end

  def cast(%{"id" => object}), do: cast(object)

  def cast(_) do
    :error
  end

  def dump(data) do
    {:ok, data}
  end

  def load(data) do
    {:ok, data}
  end
end
