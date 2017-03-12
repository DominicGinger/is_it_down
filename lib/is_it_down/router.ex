defmodule IsItDown.Router do
  import Plug.Conn
  use Plug.Router

  @endpoints File.read!("endpoints.json")

  plug Plug.Static,
    at: "/ui",
    from: "ui"

  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "Success!")
  end

  get "/endpoints" do
    send_resp(conn,200, @endpoints)
  end

  get "/check" do
    conn = fetch_query_params(conn)
    %{ "url" => url } = conn.params
    HTTPoison.start
    %HTTPoison.Response{ status_code: status_code } = HTTPoison.get! url
    send_resp(conn, 200, Integer.to_string(status_code))
  end

  def start_link do
    Plug.Adapters.Cowboy.http(IsItDown.Router, [])
  end
end
