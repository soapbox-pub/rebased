# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.InstanceStaticTest do
  use Pleroma.Web.ConnCase

  @dir "test/tmp/instance_static"

  setup do
    File.mkdir_p!(@dir)
    on_exit(fn -> File.rm_rf(@dir) end)
  end

  setup do: clear_config([:instance, :static_dir], @dir)

  test "overrides index" do
    bundled_index = get(build_conn(), "/")
    refute html_response(bundled_index, 200) == "hello world"

    File.write!(@dir <> "/index.html", "hello world")

    index = get(build_conn(), "/")
    assert html_response(index, 200) == "hello world"
  end

  test "also overrides frontend files", %{conn: conn} do
    name = "pelmora"
    ref = "uguu"

    clear_config([:frontends, :primary], %{"name" => name, "ref" => ref})

    bundled_index = get(conn, "/")
    refute html_response(bundled_index, 200) == "from frontend plug"

    path = "#{@dir}/frontends/#{name}/#{ref}"
    File.mkdir_p!(path)
    File.write!("#{path}/index.html", "from frontend plug")

    index = get(conn, "/")
    assert html_response(index, 200) == "from frontend plug"

    File.write!(@dir <> "/index.html", "from instance static")

    index = get(conn, "/")
    assert html_response(index, 200) == "from instance static"
  end

  test "overrides any file in static/static" do
    bundled_index = get(build_conn(), "/static/terms-of-service.html")

    assert html_response(bundled_index, 200) ==
             File.read!("priv/static/static/terms-of-service.html")

    File.mkdir!(@dir <> "/static")
    File.write!(@dir <> "/static/terms-of-service.html", "plz be kind")

    index = get(build_conn(), "/static/terms-of-service.html")
    assert html_response(index, 200) == "plz be kind"

    File.write!(@dir <> "/static/kaniini.html", "<h1>rabbit hugs as a service</h1>")
    index = get(build_conn(), "/static/kaniini.html")
    assert html_response(index, 200) == "<h1>rabbit hugs as a service</h1>"
  end

  test "does not sanitize dangerous files in general, as there can be html and javascript files legitimately in this folder" do
    # Create a file with a potentially dangerous extension (.json)
    # This mimics an attacker trying to serve ActivityPub JSON with a static file
    File.mkdir!(@dir <> "/static")
    File.write!(@dir <> "/static/malicious.json", "{\"type\": \"ActivityPub\"}")

    conn = get(build_conn(), "/static/malicious.json")

    assert conn.status == 200

    content_type =
      Enum.find_value(conn.resp_headers, fn
        {"content-type", value} -> value
        _ -> nil
      end)

    assert content_type == "application/json"

    File.write!(@dir <> "/static/safe.jpg", "fake image data")

    conn = get(build_conn(), "/static/safe.jpg")

    assert conn.status == 200

    # Get the content-type
    content_type =
      Enum.find_value(conn.resp_headers, fn
        {"content-type", value} -> value
        _ -> nil
      end)

    assert content_type == "image/jpeg"
  end

  test "always sanitizes emojis to images" do
    File.mkdir!(@dir <> "/emoji")
    File.write!(@dir <> "/emoji/malicious.html", "<script>HACKED</script>")

    # Request the malicious file
    conn = get(build_conn(), "/emoji/malicious.html")

    # Verify the file was served (status 200)
    assert conn.status == 200

    # The content should be served, but with a sanitized content-type
    content_type =
      Enum.find_value(conn.resp_headers, fn
        {"content-type", value} -> value
        _ -> nil
      end)

    # It should have been sanitized to application/octet-stream because "application"
    # is not in the allowed_mime_types list
    assert content_type == "application/octet-stream"

    # Create a file with an allowed extension (.jpg)
    File.write!(@dir <> "/emoji/safe.jpg", "fake image data")

    # Request the safe file
    conn = get(build_conn(), "/emoji/safe.jpg")

    # Verify the file was served (status 200)
    assert conn.status == 200

    # Get the content-type
    content_type =
      Enum.find_value(conn.resp_headers, fn
        {"content-type", value} -> value
        _ -> nil
      end)

    # It should be preserved because "image" is in the allowed_mime_types list
    assert content_type == "image/jpeg"
  end
end
