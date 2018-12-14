defmodule Pleroma.Captcha do
  use GenServer

  @ets __MODULE__.Ets
  @ets_options [:ordered_set, :private, :named_table, {:read_concurrency, true}]


  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end


  @doc false
  def init(_) do
    @ets = :ets.new(@ets, @ets_options)

    {:ok, nil}
  end

  def new() do
    GenServer.call(__MODULE__, :new)
  end

  def validate(token, captcha) do
    GenServer.call(__MODULE__, {:validate, token, captcha})
  end

  @doc false
  def handle_call(:new, _from, state) do
    enabled = Pleroma.Config.get([__MODULE__, :enabled])

    if !enabled do
      {
        :reply,
        %{type: :none},
        state
      }
    else
      method = Pleroma.Config.get!([__MODULE__, :method])

      case method do
        __MODULE__.Kocaptcha ->
          endpoint = Pleroma.Config.get!([method, :endpoint])
          case HTTPoison.get(endpoint <> "/new") do
            {:error, _} ->
              %{error: "Kocaptcha service unavailable"}
            {:ok, res} ->
              json_resp = Poison.decode!(res.body)

              token = json_resp["token"]

              true = :ets.insert(@ets, {token, json_resp["md5"]})

              {
                :reply,
                %{type: :kocaptcha, token: token, url: endpoint <> json_resp["url"]},
                state
              }
          end
      end
    end
  end

  @doc false
  def handle_call({:validate, token, captcha}, _from, state) do
    with false <- is_nil(captcha),
         [{^token, saved_md5}] <- :ets.lookup(@ets, token),
         true <- (:crypto.hash(:md5, captcha) |> Base.encode16) == String.upcase(saved_md5) do
      # Clear the saved value
      :ets.delete(@ets, token)

      {:reply, true, state}
    else
      e -> IO.inspect(e); {:reply, false, state}
    end
  end
end
