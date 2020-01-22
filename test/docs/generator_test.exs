defmodule Pleroma.Docs.GeneratorTest do
  use ExUnit.Case, async: true
  alias Pleroma.Docs.Generator

  @descriptions [
    %{
      group: :pleroma,
      key: Pleroma.Upload,
      type: :group,
      description: "",
      children: [
        %{
          key: :uploader,
          type: :module,
          description: "",
          suggestions:
            Generator.list_modules_in_dir(
              "lib/pleroma/upload/filter",
              "Elixir.Pleroma.Upload.Filter."
            )
        },
        %{
          key: :filters,
          type: {:list, :module},
          description: "",
          suggestions:
            Generator.list_modules_in_dir(
              "lib/pleroma/web/activity_pub/mrf",
              "Elixir.Pleroma.Web.ActivityPub.MRF."
            )
        },
        %{
          key: Pleroma.Upload,
          type: :string,
          description: "",
          suggestions: [""]
        },
        %{
          key: :some_key,
          type: :keyword,
          description: "",
          suggestions: [],
          children: [
            %{
              key: :another_key,
              type: :integer,
              description: "",
              suggestions: [5]
            },
            %{
              key: :another_key_with_label,
              label: "Another label",
              type: :integer,
              description: "",
              suggestions: [7]
            }
          ]
        },
        %{
          key: :key1,
          type: :atom,
          description: "",
          suggestions: [
            :atom,
            Pleroma.Upload,
            {:tuple, "string", 8080},
            [:atom, Pleroma.Upload, {:atom, Pleroma.Upload}]
          ]
        },
        %{
          key: Pleroma.Upload,
          label: "Special Label",
          type: :string,
          description: "",
          suggestions: [""]
        },
        %{
          group: {:subgroup, Swoosh.Adapters.SMTP},
          key: :auth,
          type: :atom,
          description: "`Swoosh.Adapters.SMTP` adapter specific setting",
          suggestions: [:always, :never, :if_available]
        },
        %{
          key: "application/xml",
          type: {:list, :string},
          suggestions: ["xml"]
        },
        %{
          key: :versions,
          type: {:list, :atom},
          description: "List of TLS version to use",
          suggestions: [:tlsv1, ":tlsv1.1", ":tlsv1.2"]
        }
      ]
    },
    %{
      group: :tesla,
      key: :adapter,
      type: :group,
      description: ""
    },
    %{
      group: :cors_plug,
      type: :group,
      children: [%{key: :key1, type: :string, suggestions: [""]}]
    },
    %{group: "Some string group", key: "Some string key", type: :group}
  ]

  describe "convert_to_strings/1" do
    test "group, key, label" do
      [desc1, desc2 | _] = Generator.convert_to_strings(@descriptions)

      assert desc1[:group] == ":pleroma"
      assert desc1[:key] == "Pleroma.Upload"
      assert desc1[:label] == "Pleroma.Upload"

      assert desc2[:group] == ":tesla"
      assert desc2[:key] == ":adapter"
      assert desc2[:label] == "Adapter"
    end

    test "group without key" do
      descriptions = Generator.convert_to_strings(@descriptions)
      desc = Enum.at(descriptions, 2)

      assert desc[:group] == ":cors_plug"
      refute desc[:key]
      assert desc[:label] == "Cors plug"
    end

    test "children key, label, type" do
      [%{children: [child1, child2, child3, child4 | _]} | _] =
        Generator.convert_to_strings(@descriptions)

      assert child1[:key] == ":uploader"
      assert child1[:label] == "Uploader"
      assert child1[:type] == :module

      assert child2[:key] == ":filters"
      assert child2[:label] == "Filters"
      assert child2[:type] == {:list, :module}

      assert child3[:key] == "Pleroma.Upload"
      assert child3[:label] == "Pleroma.Upload"
      assert child3[:type] == :string

      assert child4[:key] == ":some_key"
      assert child4[:label] == "Some key"
      assert child4[:type] == :keyword
    end

    test "child with predefined label" do
      [%{children: children} | _] = Generator.convert_to_strings(@descriptions)
      child = Enum.at(children, 5)
      assert child[:key] == "Pleroma.Upload"
      assert child[:label] == "Special Label"
    end

    test "subchild" do
      [%{children: children} | _] = Generator.convert_to_strings(@descriptions)
      child = Enum.at(children, 3)
      %{children: [subchild | _]} = child

      assert subchild[:key] == ":another_key"
      assert subchild[:label] == "Another key"
      assert subchild[:type] == :integer
    end

    test "subchild with predefined label" do
      [%{children: children} | _] = Generator.convert_to_strings(@descriptions)
      child = Enum.at(children, 3)
      %{children: subchildren} = child
      subchild = Enum.at(subchildren, 1)

      assert subchild[:key] == ":another_key_with_label"
      assert subchild[:label] == "Another label"
    end

    test "module suggestions" do
      [%{children: [%{suggestions: suggestions} | _]} | _] =
        Generator.convert_to_strings(@descriptions)

      Enum.each(suggestions, fn suggestion ->
        assert String.starts_with?(suggestion, "Pleroma.")
      end)
    end

    test "atoms in suggestions with leading `:`" do
      [%{children: children} | _] = Generator.convert_to_strings(@descriptions)
      %{suggestions: suggestions} = Enum.at(children, 4)
      assert Enum.at(suggestions, 0) == ":atom"
      assert Enum.at(suggestions, 1) == "Pleroma.Upload"
      assert Enum.at(suggestions, 2) == {":tuple", "string", 8080}
      assert Enum.at(suggestions, 3) == [":atom", "Pleroma.Upload", {":atom", "Pleroma.Upload"}]

      %{suggestions: suggestions} = Enum.at(children, 6)
      assert Enum.at(suggestions, 0) == ":always"
      assert Enum.at(suggestions, 1) == ":never"
      assert Enum.at(suggestions, 2) == ":if_available"
    end

    test "group, key as string in main desc" do
      descriptions = Generator.convert_to_strings(@descriptions)
      desc = Enum.at(descriptions, 3)
      assert desc[:group] == "Some string group"
      assert desc[:key] == "Some string key"
    end

    test "key as string subchild" do
      [%{children: children} | _] = Generator.convert_to_strings(@descriptions)
      child = Enum.at(children, 7)
      assert child[:key] == "application/xml"
    end

    test "suggestion for tls versions" do
      [%{children: children} | _] = Generator.convert_to_strings(@descriptions)
      child = Enum.at(children, 8)
      assert child[:suggestions] == [":tlsv1", ":tlsv1.1", ":tlsv1.2"]
    end

    test "subgroup with module name" do
      [%{children: children} | _] = Generator.convert_to_strings(@descriptions)

      %{group: subgroup} = Enum.at(children, 6)
      assert subgroup == {":subgroup", "Swoosh.Adapters.SMTP"}
    end
  end
end
