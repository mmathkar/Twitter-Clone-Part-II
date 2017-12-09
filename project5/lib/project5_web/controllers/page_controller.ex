defmodule Project5Web.PageController do
  use Project5Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
