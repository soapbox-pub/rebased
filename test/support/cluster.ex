defmodule Pleroma.Cluster do
  @moduledoc """
  Facilities for managing a cluster of slave VM's for federated testing.

  ## Spawning the federated cluster

  `spawn_cluster/1` spawns a map of slave nodes that are started
  within the running VM. During startup, the slave node is sent all configuration
  from the parent node, as well as all code. After receiving configuration and
  code, the slave then starts all applications currently running on the parent.
  The configuration passed to `spawn_cluster/1` overrides any parent application
  configuration for the provided OTP app and key. This is useful for customizing
  the Ecto database, Phoenix webserver ports, etc.

  For example, to start a single federated VM named ":federated1", with the
  Pleroma Endpoint running on port 4123, and with a database named
  "pleroma_test1", you would run:

    endpoint_conf = Application.fetch_env!(:pleroma, Pleroma.Web.Endpoint)
    repo_conf = Application.fetch_env!(:pleroma, Pleroma.Repo)

    Pleroma.Cluster.spawn_cluster(%{
      :"federated1@127.0.0.1" => [
        {:pleroma, Pleroma.Repo, Keyword.merge(repo_conf, database: "pleroma_test1")},
        {:pleroma, Pleroma.Web.Endpoint,
        Keyword.merge(endpoint_conf, http: [port: 4011], url: [port: 4011], server: true)}
      ]
    })

  *Note*: application configuration for a given key is not merged,
  so any customization requires first fetching the existing values
  and merging yourself by providing the merged configuration,
  such as above with the endpoint config and repo config.

  ## Executing code within a remote node

  Use the `within/2` macro to execute code within the context of a remote
  federated node. The code block captures all local variable bindings from
  the parent's context and returns the result of the expression after executing
  it on the remote node. For example:

      import Pleroma.Cluster

      parent_value = 123

      result =
        within :"federated1@127.0.0.1" do
          {node(), parent_value}
        end

      assert result == {:"federated1@127.0.0.1, 123}

  *Note*: while local bindings are captured and available within the block,
  other parent contexts like required, aliased, or imported modules are not
  in scope. Those will need to be reimported/aliases/required within the block
  as `within/2` is a remote procedure call.
  """

  @extra_apps Pleroma.Mixfile.application()[:extra_applications]

  @doc """
  Spawns the default Pleroma federated cluster.

  Values before may be customized as needed for the test suite.
  """
  def spawn_default_cluster do
    endpoint_conf = Application.fetch_env!(:pleroma, Pleroma.Web.Endpoint)
    repo_conf = Application.fetch_env!(:pleroma, Pleroma.Repo)

    spawn_cluster(%{
      :"federated1@127.0.0.1" => [
        {:pleroma, Pleroma.Repo, Keyword.merge(repo_conf, database: "pleroma_test_federated1")},
        {:pleroma, Pleroma.Web.Endpoint,
         Keyword.merge(endpoint_conf, http: [port: 4011], url: [port: 4011], server: true)}
      ],
      :"federated2@127.0.0.1" => [
        {:pleroma, Pleroma.Repo, Keyword.merge(repo_conf, database: "pleroma_test_federated2")},
        {:pleroma, Pleroma.Web.Endpoint,
         Keyword.merge(endpoint_conf, http: [port: 4012], url: [port: 4012], server: true)}
      ]
    })
  end

  @doc """
  Spawns a configured map of federated nodes.

  See `Pleroma.Cluster` module documentation for details.
  """
  def spawn_cluster(node_configs) do
    # Turn node into a distributed node with the given long name
    :net_kernel.start([:"primary@127.0.0.1"])

    # Allow spawned nodes to fetch all code from this node
    {:ok, _} = :erl_boot_server.start([])
    allow_boot("127.0.0.1")

    silence_logger_warnings(fn ->
      node_configs
      |> Enum.map(&Task.async(fn -> start_slave(&1) end))
      |> Enum.map(&Task.await(&1, 60_000))
    end)
  end

  @doc """
  Executes block of code again remote node.

  See `Pleroma.Cluster` module documentation for details.
  """
  defmacro within(node, do: block) do
    quote do
      rpc(unquote(node), unquote(__MODULE__), :eval_quoted, [
        unquote(Macro.escape(block)),
        binding()
      ])
    end
  end

  @doc false
  def eval_quoted(block, binding) do
    {result, _binding} = Code.eval_quoted(block, binding, __ENV__)
    result
  end

  defp start_slave({node_host, override_configs}) do
    log(node_host, "booting federated VM")
    {:ok, node} = :slave.start(~c"127.0.0.1", node_name(node_host), vm_args())
    add_code_paths(node)
    load_apps_and_transfer_configuration(node, override_configs)
    ensure_apps_started(node)
    {:ok, node}
  end

  def rpc(node, module, function, args) do
    :rpc.block_call(node, module, function, args)
  end

  defp vm_args do
    ~c"-loader inet -hosts 127.0.0.1 -setcookie #{:erlang.get_cookie()}"
  end

  defp allow_boot(host) do
    {:ok, ipv4} = :inet.parse_ipv4_address(~c"#{host}")
    :ok = :erl_boot_server.add_slave(ipv4)
  end

  defp add_code_paths(node) do
    rpc(node, :code, :add_paths, [:code.get_path()])
  end

  defp load_apps_and_transfer_configuration(node, override_configs) do
    Enum.each(Application.loaded_applications(), fn {app_name, _, _} ->
      app_name
      |> Application.get_all_env()
      |> Enum.each(fn {key, primary_config} ->
        rpc(node, Application, :put_env, [app_name, key, primary_config, [persistent: true]])
      end)
    end)

    Enum.each(override_configs, fn {app_name, key, val} ->
      rpc(node, Application, :put_env, [app_name, key, val, [persistent: true]])
    end)
  end

  defp log(node, msg), do: IO.puts("[#{node}] #{msg}")

  defp ensure_apps_started(node) do
    loaded_names = Enum.map(Application.loaded_applications(), fn {name, _, _} -> name end)
    app_names = @extra_apps ++ (loaded_names -- @extra_apps)

    rpc(node, Application, :ensure_all_started, [:mix])
    rpc(node, Mix, :env, [Mix.env()])
    rpc(node, __MODULE__, :prepare_database, [])

    log(node, "starting application")

    Enum.reduce(app_names, MapSet.new(), fn app, loaded ->
      if Enum.member?(loaded, app) do
        loaded
      else
        {:ok, started} = rpc(node, Application, :ensure_all_started, [app])
        MapSet.union(loaded, MapSet.new(started))
      end
    end)
  end

  @doc false
  def prepare_database do
    log(node(), "preparing database")
    repo_config = Application.get_env(:pleroma, Pleroma.Repo)
    repo_config[:adapter].storage_down(repo_config)
    repo_config[:adapter].storage_up(repo_config)

    {:ok, _, _} =
      Ecto.Migrator.with_repo(Pleroma.Repo, fn repo ->
        Ecto.Migrator.run(repo, :up, log: false, all: true)
      end)

    Ecto.Adapters.SQL.Sandbox.mode(Pleroma.Repo, :manual)
    {:ok, _} = Application.ensure_all_started(:ex_machina)
  end

  defp silence_logger_warnings(func) do
    prev_level = Logger.level()
    Logger.configure(level: :error)
    res = func.()
    Logger.configure(level: prev_level)

    res
  end

  defp node_name(node_host) do
    node_host
    |> to_string()
    |> String.split("@")
    |> Enum.at(0)
    |> String.to_atom()
  end
end
