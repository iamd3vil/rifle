defmodule Rifle.Connection do
  @moduledoc """
  GenServer which holds gun connections.
  """
  use GenServer

  def start_link(%{name: name, domain: domain, port: port}) do
    IO.inspect("Starting: #{name}")
    GenServer.start_link(__MODULE__, %{domain: domain, port: port}, name: :"#{name}")
  end

  def init(%{domain: domain, port: port}) do
    {:ok, conn} = :gun.open(String.to_charlist(domain), port)

    case :gun.await_up(conn) do
      {:error, reason} -> {:stop, reason}
      {:ok, _} -> {:ok, %{conn: conn, refs: %{}}}
    end
  end

  def handle_call({:request, method, path, headers, body, req_opts}, from, state) do
    stream_ref = :gun.request(state.conn, method, path, headers, body, req_opts)

    # Add stream_ref to state.
    state =
      put_in(state, [:refs, stream_ref], %{from: from, body: "", headers: [], status_code: 200})

    {:noreply, state}
  end

  def handle_info({:gun_response, _, stream_ref, :nofin, status_code, headers}, state) do
    IO.inspect("Got resp with nofin")
    from = get_in(state, [:refs, stream_ref, :from])

    state =
      put_in(state, [:refs, stream_ref], %{
        from: from,
        body: "",
        headers: headers,
        status_code: status_code
      })

    {:noreply, state}
  end

  def handle_info({:gun_response, _, stream_ref, :fin, status_code, headers}, state) do
    IO.inspect("Got resp with fin")
    from = get_in(state, [:refs, stream_ref, :from])

    state =
      put_in(state, [:refs, stream_ref], %{
        from: from,
        body: "",
        headers: headers,
        status_code: status_code
      })

    state = respond(state, stream_ref)
    {:noreply, state}
  end

  def handle_info({:gun_data, _, stream_ref, :nofin, data}, state) do
    IO.inspect("Got data with nofin")
    body = get_in(state, [:refs, stream_ref, :body])
    state = put_in(state, [:refs, stream_ref, :body], body <> data)
    {:noreply, state}
  end

  def handle_info({:gun_data, _, stream_ref, :fin, data}, state) do
    IO.inspect("Got data with fin: #{inspect(data)}")
    body = get_in(state, [:refs, stream_ref, :body])
    state = put_in(state, [:refs, stream_ref, :body], body <> data)
    state = respond(state, stream_ref)
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp respond(state, stream_ref) do
    %{from: from, body: body, headers: headers, status_code: status_code} =
      get_in(state, [:refs, stream_ref])

    GenServer.reply(from, %{body: body, headers: headers, status_code: status_code})
    %{refs: refs} = state
    refs = Map.delete(refs, stream_ref)
    Map.put(state, :refs, refs)
  end
end
