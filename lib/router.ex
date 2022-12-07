defmodule Router do
  use Plug.Router

  plug(Plug.Logger)
  plug(Plug.Static, at: "/", from: "testsite")
  plug(:match)
  plug(:dispatch)

  match "/" do
    index_path = Path.join(["testsite", "index.html"])

    send_file(conn, 200, index_path)
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
