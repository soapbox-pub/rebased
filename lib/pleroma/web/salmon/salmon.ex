defmodule Pleroma.Web.Salmon do
  @httpoison Application.get_env(:pleroma, :httpoison)

  use Bitwise
  alias Pleroma.Web.XML
  alias Pleroma.Web.OStatus.ActivityRepresenter
  alias Pleroma.User
  require Logger

  def decode(salmon) do
    doc = XML.parse_document(salmon)

    {:xmlObj, :string, data} = :xmerl_xpath.string('string(//me:data[1])', doc)
    {:xmlObj, :string, sig} = :xmerl_xpath.string('string(//me:sig[1])', doc)
    {:xmlObj, :string, alg} = :xmerl_xpath.string('string(//me:alg[1])', doc)
    {:xmlObj, :string, encoding} = :xmerl_xpath.string('string(//me:encoding[1])', doc)
    {:xmlObj, :string, type} = :xmerl_xpath.string('string(//me:data[1]/@type)', doc)

    {:ok, data} = Base.url_decode64(to_string(data), ignore: :whitespace)
    {:ok, sig} = Base.url_decode64(to_string(sig), ignore: :whitespace)
    alg = to_string(alg)
    encoding = to_string(encoding)
    type = to_string(type)

    [data, type, encoding, alg, sig]
  end

  def fetch_magic_key(salmon) do
    with [data, _, _, _, _] <- decode(salmon),
         doc <- XML.parse_document(data),
         uri when not is_nil(uri) <- XML.string_from_xpath("/entry/author[1]/uri", doc),
         {:ok, %{info: %{"magic_key" => magic_key}}} <- Pleroma.Web.OStatus.find_or_make_user(uri) do
      {:ok, magic_key}
    end
  end

  def decode_and_validate(magickey, salmon) do
    [data, type, encoding, alg, sig] = decode(salmon)

    signed_text = [data, type, encoding, alg]
    |> Enum.map(&Base.url_encode64/1)
    |> Enum.join(".")

    key = decode_key(magickey)

    verify = :public_key.verify(signed_text, :sha256, sig, key)

    if verify do
      {:ok, data}
    else
      :error
    end
  end

  def decode_key("RSA." <> magickey) do
    make_integer = fn(bin) ->
      list = :erlang.binary_to_list(bin)
      Enum.reduce(list, 0, fn (el, acc) -> (acc <<< 8) ||| el end)
    end

    [modulus, exponent] = magickey
    |> String.split(".")
    |> Enum.map(fn (n) -> Base.url_decode64!(n, padding: false) end)
    |> Enum.map(make_integer)

    {:RSAPublicKey, modulus, exponent}
  end

  def encode_key({:RSAPublicKey, modulus, exponent}) do
    modulus_enc = :binary.encode_unsigned(modulus) |> Base.url_encode64
    exponent_enc = :binary.encode_unsigned(exponent) |> Base.url_encode64

    "RSA.#{modulus_enc}.#{exponent_enc}"
  end

  def generate_rsa_pem do
    port = Port.open({:spawn, "openssl genrsa"}, [:binary])
    {:ok, pem} = receive do
      {^port, {:data, pem}} -> {:ok, pem}
    end
    Port.close(port)
    if Regex.match?(~r/RSA PRIVATE KEY/, pem) do
      {:ok, pem}
    else
      :error
    end
  end

  def keys_from_pem(pem) do
    [private_key_code] = :public_key.pem_decode(pem)
    private_key = :public_key.pem_entry_decode(private_key_code)
    {:RSAPrivateKey, _, modulus, exponent, _, _, _, _, _, _, _} = private_key
    public_key = {:RSAPublicKey, modulus, exponent}
    {:ok, private_key, public_key}
  end

  def encode(private_key, doc) do
    type = "application/atom+xml"
    encoding = "base64url"
    alg = "RSA-SHA256"

    signed_text = [doc, type, encoding, alg]
    |> Enum.map(&Base.url_encode64/1)
    |> Enum.join(".")

    signature = signed_text
    |> :public_key.sign(:sha256, private_key)
    |> to_string
    |> Base.url_encode64

    doc_base64 = doc
    |> Base.url_encode64

    # Don't need proper xml building, these strings are safe to leave unescaped
    salmon = """
    <?xml version="1.0" encoding="UTF-8"?>
    <me:env xmlns:me="http://salmon-protocol.org/ns/magic-env">
      <me:data type="application/atom+xml">#{doc_base64}</me:data>
      <me:encoding>#{encoding}</me:encoding>
      <me:alg>#{alg}</me:alg>
      <me:sig>#{signature}</me:sig>
    </me:env>
    """

    {:ok, salmon}
  end

  def remote_users(%{data: %{"to" => to}}) do
    to
    |> Enum.map(fn(id) -> User.get_cached_by_ap_id(id) end)
    |> Enum.filter(fn(user) -> user && !user.local end)
  end

  defp send_to_user(%{info: %{"salmon" => salmon}}, feed, poster) do
    with {:ok, %{status_code: code}} <- poster.(salmon, feed, [{"Content-Type", "application/magic-envelope+xml"}], timeout: 10000, recv_timeout: 20000) do
      Logger.debug(fn -> "Pushed to #{salmon}, code #{code}" end)
    else
      e -> Logger.debug(fn -> "Pushing salmon to #{salmon} failed, #{inspect(e)}" end)
    end
  end

  defp send_to_user(_,_,_), do: nil

  def publish(user, activity, poster \\ &@httpoison.post/4)
  def publish(%{info: %{"keys" => keys}} = user, activity, poster) do
    feed = ActivityRepresenter.to_simple_form(activity, user, true)
    |> ActivityRepresenter.wrap_with_entry
    |> :xmerl.export_simple(:xmerl_xml)
    |> to_string

    if feed do
      {:ok, private, _} = keys_from_pem(keys)
      {:ok, feed} = encode(private, feed)

      remote_users(activity)
      |> Enum.each(fn(remote_user) ->
        Task.start(fn ->
          Logger.debug(fn -> "sending salmon to #{remote_user.ap_id}" end)
          send_to_user(remote_user, feed, poster)
        end)
      end)
    end
  end

  def publish(%{id: id}, _, _), do: Logger.debug(fn -> "Keys missing for user #{id}" end)
end
