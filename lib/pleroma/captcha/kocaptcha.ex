defmodule Pleroma.Captcha.Kocaptcha do
  alias Calendar.DateTime

  alias Pleroma.Captcha.Service
  @behaviour Service

  @ets __MODULE__.Ets

  @impl Service
  def new() do
    endpoint = Pleroma.Config.get!([__MODULE__, :endpoint])

    case Tesla.get(endpoint <> "/new") do
      {:error, _} ->
        %{error: "Kocaptcha service unavailable"}

      {:ok, res} ->
        json_resp = Poison.decode!(res.body)

        token = json_resp["token"]

        true = :ets.insert(@ets, {token, json_resp["md5"], DateTime.now_utc()})

        %{type: :kocaptcha, token: token, url: endpoint <> json_resp["url"]}
    end
  end

  @impl Service
  def validate(token, captcha) do
    with false <- is_nil(captcha),
         [{^token, saved_md5, _}] <- :ets.lookup(@ets, token),
         true <- :crypto.hash(:md5, captcha) |> Base.encode16() == String.upcase(saved_md5) do
      # Clear the saved value
      :ets.delete(@ets, token)

      true
    else
      _ -> false
    end
  end

  @impl Service
  def cleanup() do
    seconds_retained = Pleroma.Config.get!([Pleroma.Captcha, :seconds_retained])

    # Go through captchas and remove expired ones
    :ets.tab2list(@ets)
    |> Enum.each(fn {token, _, time_inserted} ->
      # time created + expiration time = time when the captcha should be removed
      remove_time = DateTime.add!(time_inserted, seconds_retained)
      if DateTime.after?(DateTime.now_utc(), remove_time), do: :ets.delete(@ets, token)
    end)

    :ok
  end
end
