defmodule Rifle do
  @moduledoc """
  Starts a pool of connections.
  """
  @default_pool_size 50

  use Supervisor

  def start_link(args) do
    opts = %{pool_size: @default_pool_size} |> Map.merge(args)
    :ets.new(args.name, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(args.name, {:options, opts})
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    children =
      for i <- 0..(opts.pool_size - 1) do
        Supervisor.child_spec(
          {Rifle.Connection, %{opts | name: "#{opts.name}_#{i}"}},
          id: "#{opts.name}_#{i}"
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  def request(svc_name, method, path, body, headers \\ [], req_opts \\ %{}) do
    # Get opts
    [{:options, opts}] = :ets.lookup(svc_name, :options)

    index = random_index(opts.pool_size)

    try do
      GenServer.call(:"#{opts.name}_#{index}", {:request, method, path, headers, body, req_opts})
    catch
      :exit, _ -> {:error, :timeout}
    end
  end

  defp random_index(pool_size) do
    rem(System.unique_integer([:positive]), pool_size)
  end
end
