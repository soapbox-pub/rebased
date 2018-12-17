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

        true =
          :ets.insert(
            @ets,
            {token, json_resp["md5"], DateTime.now_utc() |> DateTime.Format.unix()}
          )

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
    # If the time in ETS is less than current_time - seconds_retained, then the time has
    # already passed
    delete_after =
      DateTime.subtract!(DateTime.now_utc(), seconds_retained) |> DateTime.Format.unix()

    :ets.select_delete(
      @ets,
      [
        {
          {:_, :_, :"$1"},
          [{:<, :"$1", {:const, delete_after}}],
          [true]
        }
      ]
    )

    :ok
  end
end
