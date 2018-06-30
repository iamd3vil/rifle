defmodule Rifle.Connection do
  @moduledoc """
  GenServer which holds gun connections. This can handle multiple requests at the same time.
  """
  use GenServer
  require Logger

  def start_link(%{name: name, domain: domain, port: port}) do
    IO.inspect("Starting: #{name}")
    GenServer.start_link(__MODULE__, %{domain: domain, port: port}, name: :"#{name}")
  end

  def init(%{domain: domain, port: port}) do
    {:ok, conn} = :gun.open(String.to_charlist(domain), port)

    # Wait until gun can establish a connection. If it can't that means we can't start the connection.
    # TODO: Better error messages here. 
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

    # Returning `:noreply` since we can't reply here. Once gun gives response and data then we can respond.
    # This is why we are storing `from` so that we can use `GenServer.reply/2` later to respond.
    {:noreply, state}
  end

  def handle_info({:gun_response, _, stream_ref, :nofin, status_code, headers}, state) do
    from = get_in(state, [:refs, stream_ref, :from])

    # Put in headers and status code. Don't respond since we have to receive `gun_data`
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
    from = get_in(state, [:refs, stream_ref, :from])

    state =
      put_in(state, [:refs, stream_ref], %{
        from: from,
        body: "",
        headers: headers,
        status_code: status_code
      })

    # Since we got `:fin` there will be no more `:gun_data` messages.
    # So we have to respond with an empty body.
    state = respond(state, stream_ref)
    {:noreply, state}
  end

  def handle_info({:gun_data, _, stream_ref, :nofin, data}, state) do
    body = get_in(state, [:refs, stream_ref, :body])

    # We got `:nofin`, so there will be more `:gun_data` messages.
    # Just save body and wait for more `:gun_data` messages.
    state = put_in(state, [:refs, stream_ref, :body], body <> data)
    {:noreply, state}
  end

  def handle_info({:gun_data, _, stream_ref, :fin, data}, state) do
    body = get_in(state, [:refs, stream_ref, :body])
    state = put_in(state, [:refs, stream_ref, :body], body <> data)

    # Since we got `:fin`, we should respond now.
    state = respond(state, stream_ref)
    {:noreply, state}
  end

  # Ignore other message now which includes `:gun_up` and `:gun_down` messages.
  # TODO: Handle `:gun_up` and `:gun_down` messages.
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
