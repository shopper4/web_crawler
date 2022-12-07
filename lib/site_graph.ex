defmodule WebCrawler.SiteGraph do
  use GenServer
  alias Graph

  @moduledoc """
  GenSever that holds the sitemap state.
  """

  defstruct root_host: %URI{}, graph: Graph.new(), cache: %{}, visited_urls: []

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: WebCrawler.SiteGraph)
  end

  @impl true
  def init(_) do
    {:ok, %WebCrawler.SiteGraph{}}
  end

  @impl true
  def handle_call({:add_page, url}, _from, state) do
    {:reply, :ok,
     %{
       state
       | graph: Graph.add_vertex(state.graph, url),
         visited_urls: [url | state.visited_urls]
     }}
  end

  @impl true
  def handle_call({:add_pages, urls}, _from, %{graph: graph} = state) do
    {:reply, :ok, %{state | graph: Graph.add_vertices(graph, urls)}}
  end

  @impl true
  def handle_call({:add_link, {url, to_url}}, _from, %{graph: graph} = state) do
    {:reply, :ok, %{state | graph: Graph.add_edge(graph, url, to_url)}}
  end

  @impl true
  def handle_call({:add_links, links}, _from, %{graph: graph} = state) do
    {:reply, :ok, %{state | graph: Graph.add_edges(graph, links)}}
  end

  @impl true
  def handle_call({:cache_page, {url, document}}, _from, %{cache: cache} = state) do
    {:reply, :ok, %{state | cache: Map.put(cache, url, document)}}
  end

  @impl true
  def handle_call({:retrieve_cached_page, url}, _from, %{cache: cache} = state) do
    {:reply, Map.get(cache, url), state}
  end

  @impl true
  def handle_call({:visited_url?, url}, _from, state) do
    {:reply, Enum.member?(state.visited_urls, url), state}
  end

  @impl true
  def handle_call({:reset_state, root_host}, _from, _state) do
    {:reply, {:ok, root_host}, %WebCrawler.SiteGraph{root_host: root_host}}
  end

  @impl true
  def handle_call(:get_root_host, _from, state) do
    {:reply, state.root_host, state}
  end

  @impl true
  def handle_cast({:output, :dot}, %{graph: graph} = state) do
    {:ok, dot} = Graph.to_dot(graph)
    File.write!("./out.dot", dot)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:output, :sitemap}, %{graph: graph} = state) do
    urls =
      graph
      |> Graph.vertices()
      |> Enum.map(fn url ->
        XmlBuilder.element(:url, %{loc: url})
      end)

    sitemap =
      XmlBuilder.document(:urlset, urls)
      |> XmlBuilder.generate()

    File.write!("./sitemap.xml", sitemap)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:output, :log}, %{graph: graph} = state) do
    Graph.vertices(graph)
    |> Enum.reduce(%{}, fn page, acc ->
      links =
        Graph.out_edges(graph, page)
        |> Enum.map(fn %Graph.Edge{v2: linked_page} -> linked_page end)

      Map.put(acc, page, links)
    end)
    |> IO.inspect(label: "output")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:output, :json}, %{graph: graph} = state) do
    json =
      Graph.vertices(graph)
      |> Enum.reduce([], fn page, acc ->
        links =
          Graph.out_edges(graph, page)
          |> Enum.map(fn %Graph.Edge{v2: linked_page} -> linked_page end)

        acc ++ [%{"url" => page, "linked_pages" => links}]
      end)
      |> Jason.encode!(pretty: true)

    File.write!("./sitemap.json", json)

    {:noreply, state}
  end

  def add_page(url) do
    GenServer.call(__MODULE__, {:add_page, url})
  end

  def add_pages(urls) do
    GenServer.call(__MODULE__, {:add_pages, urls})
  end

  def add_link(url, to_url) do
    GenServer.call(__MODULE__, {:add_link, {url, to_url}})
  end

  @doc """
  Adds a list of links to the site graph.
  """
  def add_links(links) do
    GenServer.call(__MODULE__, {:add_links, links})
  end

  @doc """
  Adds the static asset details for a url to the page assets map.
  This is required since the graph library doesn't allow any kind of metadata to
  be attached to vertices.
  """
  def cache_page(url, document) do
    GenServer.call(__MODULE__, {:cache_page, {url, document}})
  end

  @doc """
  Attempt to retrieve a page from the cache. If not found will return nil.
  """
  def retrieve_cached_page(url) do
    GenServer.call(__MODULE__, {:retrieve_cached_page, url})
  end

  @doc """
  Checks the sitemap graph to see if a url has already been added.
  """
  def visited_url?(url) do
    GenServer.call(__MODULE__, {:visited_url?, url})
  end

  @doc """
  Outputs the sitemap in the specified format
  """
  def output(format) do
    GenServer.cast(__MODULE__, {:output, format})
  end

  @doc """
  Resets the genserver state, and sets the host URI (this is called when a new site is crawled).
  """
  def reset_state(root_host) do
    GenServer.call(__MODULE__, {:reset_state, root_host})
  end

  @doc """
  Returns the root host URI.
  """
  def get_root_host() do
    GenServer.call(__MODULE__, :get_root_host)
  end
end
