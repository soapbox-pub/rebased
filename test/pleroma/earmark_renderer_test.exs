# Pleroma: A lightweight social networking server
# Copyright © 2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.EarmarkRendererTest do
  use ExUnit.Case

  test "Paragraph" do
    code = ~s[Hello\n\nWorld!]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == "<p>Hello</p><p>World!</p>"
  end

  test "raw HTML" do
    code = ~s[<a href="http://example.org/">OwO</a><!-- what's this?-->]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == "<p>#{code}</p>"
  end

  test "rulers" do
    code = ~s[before\n\n-----\n\nafter]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == "<p>before</p><hr /><p>after</p>"
  end

  test "headings" do
    code = ~s[# h1\n## h2\n### h3\n]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == ~s[<h1>h1</h1><h2>h2</h2><h3>h3</h3>]
  end

  test "blockquote" do
    code = ~s[> whoms't are you quoting?]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == "<blockquote><p>whoms’t are you quoting?</p></blockquote>"
  end

  test "code" do
    code = ~s[`mix`]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == ~s[<p><code class="inline">mix</code></p>]

    code = ~s[``mix``]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == ~s[<p><code class="inline">mix</code></p>]

    code = ~s[```\nputs "Hello World"\n```]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == ~s[<pre><code class="">puts &quot;Hello World&quot;</code></pre>]
  end

  test "lists" do
    code = ~s[- one\n- two\n- three\n- four]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == "<ul><li>one</li><li>two</li><li>three</li><li>four</li></ul>"

    code = ~s[1. one\n2. two\n3. three\n4. four\n]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == "<ol><li>one</li><li>two</li><li>three</li><li>four</li></ol>"
  end

  test "delegated renderers" do
    code = ~s[a<br/>b]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == "<p>#{code}</p>"

    code = ~s[*aaaa~*]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == ~s[<p><em>aaaa~</em></p>]

    code = ~s[**aaaa~**]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == ~s[<p><strong>aaaa~</strong></p>]

    # strikethrought
    code = ~s[<del>aaaa~</del>]
    result = Earmark.as_html!(code, %Earmark.Options{renderer: Pleroma.EarmarkRenderer})
    assert result == ~s[<p><del>aaaa~</del></p>]
  end
end
