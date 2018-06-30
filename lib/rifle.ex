defmodule Rifle do
  @moduledoc """
  Starts a pool of connections.
  """
  @default_pool_size 50
  @supported_http_methods [
    "GET",
    "PUT",
    "POST",
    "DELETE",
    "OPTIONS",
    "HEAD",
    "TRACE"
  ]

  use Supervisor

  def start_link(args) do
    opts = %{pool_size: @default_pool_size} |> Map.merge(args)

    # Store opts in an ets table, since we need to get the opts while making requests.
    :ets.new(args.name, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(args.name, {:options, opts})

    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    # Instead of using something like `poolboy` we are just starting multiple connections.
    # `Rifle.Connection` can handle multiple requests simultaneously. So if we use pooling libs like
    # `poolboy` we are not taking advantage of the concurrency provided by `Rifle.Connection`.
    children =
      for i <- 0..(opts.pool_size - 1) do
        Supervisor.child_spec(
          {Rifle.Connection, %{opts | name: "#{opts.name}_#{i}"}},
          id: "#{opts.name}_#{i}"
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Uses `svc_name` pool to get `path`.

  Options:

  - `svc_name` - Name of the pool.
  - `path` - Path without the domain given while starting the pool.
  - `headers` - List of tuples(with binaries) which will be passed as custom headers.
  - `req_opts` - Options given to `Gun`. Has a `:timeout` of 10 seconds as default.
  """
  def get(svc_name, path, headers \\ [], req_opts \\ %{}) do
    request(svc_name, "GET", path, "", headers, req_opts)
  end

  @doc """
  Options:

  - Same as `get/4`
  - `body` needs to be binary, which will be passed as POST body.
  """
  def post(svc_name, path, body, headers \\ [], req_opts \\ %{}) do
    request(svc_name, "POST", path, body, headers, req_opts)
  end

  def put(svc_name, path, body, headers \\ [], req_opts \\ %{}) do
    request(svc_name, "PUT", path, body, headers, req_opts)
  end

  def delete(svc_name, path, body, headers \\ [], req_opts \\ %{}) do
    request(svc_name, "DELETE", path, body, headers, req_opts)
  end

  def head(svc_name, path, body, headers \\ [], req_opts \\ %{}) do
    request(svc_name, "HEAD", path, body, headers, req_opts)
  end

  def options(svc_name, path, body, headers \\ [], req_opts \\ %{}) do
    request(svc_name, "OPTIONS", path, body, headers, req_opts)
  end

  @doc """
  Can make any custom request with any HTTP `method`. For all the http functions,
  this method is used internally.

  Options:

  - `method` can be `GET`, `POST`, `PUT`, `DELETE`, `HEAD`, `OPTIONS`, `TRACE`
  - Other options are same as `post/5`
  """
  def request(svc_name, method, path, body, headers \\ [], req_opts \\ %{})
      when method in @supported_http_methods do
    # Get opts
    [{:options, opts}] = :ets.lookup(svc_name, :options)

    index = random_index(opts.pool_size)

    # Have a timeout of 10 secs as default.
    timeout = Map.get(req_opts, :timeout, 10_000)

    try do
      GenServer.call(
        :"#{opts.name}_#{index}",
        {:request, method, path, headers, body, req_opts},
        timeout
      )
    catch
      :exit, _ -> {:error, :timeout}
    end
  end

  defp random_index(pool_size) do
    rem(System.unique_integer([:positive]), pool_size)
  end
end
