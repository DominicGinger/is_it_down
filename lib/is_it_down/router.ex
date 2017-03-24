defmodule Endpoint do
  @derive [Poison.Encoder]
  defstruct [:name, :url]
end

defmodule IsItDown.Router do
  import Plug.Conn
  use Plug.Router

  @endpoints File.read!("endpoints.json")
    |> Poison.decode!(as: [%Endpoint{}])

  plug Plug.Static, at: "/ui", from: "ui"
  plug :match
  plug :dispatch

  get "/" do
    send_file(conn, 200, "ui/index.html")
  end

  get "/endpoints" do
    caller = self
    pids = @endpoints
           |> Enum.map(fn(endpoint) ->
spawn(fn ->
  send(caller, { self, { endpoint, HTTPoison.get!(endpoint.url) } })
end)
           end)

    endpoints = for pid <- pids do
      receive do
        { ^pid, { endpoint, %HTTPoison.Response{ status_code: status_code } } } ->
          Map.put(endpoint, :status_code, status_code)
        { ^pid, { endpoint, _ } } ->
          Map.put(endpoint, :status_code, 999)
      end
    end

    endpoints
    |> Poison.encode!
    |> (&send_resp(conn, 200, &1)).()
  end

  get "/check" do
    conn = fetch_query_params(conn)
    %{ "url" => url } = conn.params
    send_resp(conn, 200, get_status(url))
  end

  defp get_status(url) do
    %HTTPoison.Response{ status_code: status_code } = HTTPoison.get! url
    Integer.to_string(status_code)
  end

  def start_link do
    Plug.Adapters.Cowboy.http(IsItDown.Router, [])
  end
end
