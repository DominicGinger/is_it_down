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
    caller = self()

    #@endpoints
    #|> Enum.map(fn(endpoint) ->
    #Map.put(endpoint, :status_code, get_status(endpoint.url))
    #end)
    #|> Poison.encode!
    #|> (&send_resp(conn, 200, &1)).()

    #@endpoints
    #|> Enum.map(&spawn_request(caller, &1))
    #|> receive_requests
    #|> Poison.encode!
    #|> (&send_resp(conn, 200, &1)).()

    @endpoints
    |> Flow.from_enumerable()
    |> Flow.map(fn(endpoint) ->
      Map.put(endpoint, :status_code, get_status(endpoint.url))
    end)
    |> Enum.to_list()
    |> Poison.encode!
    |> (&send_resp(conn, 200, &1)).()
  end

  get "/check" do
    conn = fetch_query_params(conn)
    %{ "url" => url } = conn.params
    send_resp(conn, 200, get_status(url))
  end

  defp receive_requests(pids) do
    for _ <- pids do
      receive do
        { endpoint, status_code } ->
          Map.put(endpoint, :status_code, status_code)
      end
    end
  end

  defp spawn_request(caller, endpoint) do
    spawn(fn -> 
      send(caller, { endpoint, get_status(endpoint.url) })
    end)
  end

  defp get_status(url) do
    case HTTPoison.get! url do
      %HTTPoison.Response{ status_code: status_code } ->
        Integer.to_string(status_code)
    end
  end

  def start_link do
    Plug.Adapters.Cowboy.http(IsItDown.Router, [])
  end
end
