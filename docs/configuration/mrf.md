# Message Rewrite Facility

The Message Rewrite Facility (MRF) is a subsystem that is implemented as a series of hooks that allows the administrator to rewrite or discard messages.

Possible uses include:

* marking incoming messages with media from a given account or instance as sensitive
* rejecting messages from a specific instance
* rejecting reports (flags) from a specific instance
* removing/unlisting messages from the public timelines
* removing media from messages
* sending only public messages to a specific instance

The MRF provides user-configurable policies. The default policy is `NoOpPolicy`, which disables the MRF functionality. Pleroma also includes an easy to use policy called `SimplePolicy` which maps messages matching certain pre-defined criterion to actions built into the policy module.

It is possible to use multiple, active MRF policies at the same time.

## Quarantine Instances

You have the ability to prevent from private / followers-only messages from federating with specific instances. Which means they will only get the public or unlisted messages from your instance.

If, for example, you're using `MIX_ENV=prod` aka using production mode, you would open your configuration file located in `config/prod.secret.exs` and edit or add the option under your `:instance` config object. Then you would specify the instance within quotes.

```elixir
config :pleroma, :instance,
  [...]
  quarantined_instances: ["instance.example", "other.example"]
```

## Using `SimplePolicy`

`SimplePolicy` is capable of handling most common admin tasks.

To use `SimplePolicy`, you must enable it. Do so by adding the following to your `:instance` config object, so that it looks like this:

```elixir
config :pleroma, :mrf,
  [...]
  policies: Pleroma.Web.ActivityPub.MRF.SimplePolicy
```

Once `SimplePolicy` is enabled, you can configure various groups in the `:mrf_simple` config object. These groups are:

* `reject`: Servers in this group will have their messages rejected.
* `accept`: If not empty, only messages from these instances will be accepted (whitelist federation).
* `media_nsfw`: Servers in this group will have the #nsfw tag and sensitive setting injected into incoming messages which contain media.
* `media_removal`: Servers in this group will have media stripped from incoming messages.
* `avatar_removal`: Avatars from these servers will be stripped from incoming messages.
* `banner_removal`: Banner images from these servers will be stripped from incoming messages.
* `report_removal`: Servers in this group will have their reports (flags) rejected.
* `federated_timeline_removal`: Servers in this group will have their messages unlisted from the public timelines by flipping the `to` and `cc` fields.
* `reject_deletes`: Deletion requests will be rejected from these servers.

Servers should be configured as lists.

### Example

This example will enable `SimplePolicy`, block media from `illegalporn.biz`, mark media as NSFW from `porn.biz` and `porn.business`, reject messages from `spam.com`, remove messages from `spam.university` from the federated timeline and block reports (flags) from `whiny.whiner`. We also give a reason why the moderation was done:

```elixir
config :pleroma, :mrf,
  policies: [Pleroma.Web.ActivityPub.MRF.SimplePolicy]

config :pleroma, :mrf_simple,
  media_removal: [{"illegalporn.biz", "Media can contain illegal contant"}],
  media_nsfw: [{"porn.biz", "unmarked nsfw media"}, {"porn.business", "A lot of unmarked nsfw media"}],
  reject: [{"spam.com", "They keep spamming our users"}],
  federated_timeline_removal: [{"spam.university", "Annoying low-quality posts who otherwise fill up TWKN"}],
  report_removal: [{"whiny.whiner", "Keep spamming us with irrelevant reports"}]
```

### Use with Care

The effects of MRF policies can be very drastic. It is important to use this functionality carefully. Always try to talk to an admin before writing an MRF policy concerning their instance.

## Writing your own MRF Policy

As discussed above, the MRF system is a modular system that supports pluggable policies. This means that an admin may write a custom MRF policy in Elixir or any other language that runs on the Erlang VM, by specifying the module name in the `policies` config setting.

For example, here is a sample policy module which rewrites all messages to "new message content":

```elixir
defmodule Pleroma.Web.ActivityPub.MRF.RewritePolicy do
  @moduledoc "MRF policy which rewrites all Notes to have 'new message content'."
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  # Catch messages which contain Note objects with actual data to filter.
  # Capture the object as `object`, the message content as `content` and the
  # message itself as `message`.
  @impl true
  def filter(
        %{"type" => "Create", "object" => %{"type" => "Note", "content" => content} = object} =
          message
      )
      when is_binary(content) do
    # Subject / CW is stored as summary instead of `name` like other AS2 objects
    # because of Mastodon doing it that way.
    summary = object["summary"]

    # Message edits go here.
    content = "new message content"

    # Assemble the mutated object.
    object =
      object
      |> Map.put("content", content)
      |> Map.put("summary", summary)

    # Assemble the mutated message.
    message = Map.put(message, "object", object)
    {:ok, message}
  end

  # Let all other messages through without modifying them.
  @impl true
  def filter(message), do: {:ok, message}

  @impl true
  def describe do
    {:ok, %{mrf_sample: %{content: "new message content"}}}
  end
end
```

If you save this file as `lib/pleroma/web/activity_pub/mrf/rewrite_policy.ex`, it will be included when you next rebuild Pleroma.  You can enable it in the configuration like so:

```elixir
config :pleroma, :mrf,
  policies: [
    Pleroma.Web.ActivityPub.MRF.SimplePolicy,
    Pleroma.Web.ActivityPub.MRF.RewritePolicy
  ]
```

Please note that the Pleroma developers consider custom MRF policy modules to fall under the purview of the AGPL. As such, you are obligated to release the sources to your custom MRF policy modules upon request.

### MRF policies descriptions

If MRF policy depends on config, it can be added into MRF tab to adminFE by adding `config_description/0` method, which returns a map with a specific structure. See existing MRF's like `lib/pleroma/web/activity_pub/mrf/activity_expiration_policy.ex` for examples. Note that more complex inputs, like tuples or maps, may need extra changes in the adminFE and just adding it to `config_description/0` may not be enough to get these inputs working from the adminFE.

Example:

```elixir
%{
      key: :mrf_activity_expiration,
      related_policy: "Pleroma.Web.ActivityPub.MRF.ActivityExpirationPolicy",
      label: "MRF Activity Expiration Policy",
      description: "Adds automatic expiration to all local activities",
      children: [
        %{
          key: :days,
          type: :integer,
          description: "Default global expiration time for all local activities (in days)",
          suggestions: [90, 365]
        }
      ]
    }
```
