defmodule WebCrawler do
  use Application
  alias WebCrawler.SiteGraph
  require Logger

  @moduledoc """
  Basic web page crawler written by Sam Hopper for a technical interview task.
  Uses a directed graph to keep track of the pages and the links between them.
  """

  @max_depth 3
  @timeout 30_000

  def start(_type, _args) do
    children = [
      {WebCrawler.SiteGraph, name: WebCrawler.SiteGraph},
      {Plug.Cowboy, scheme: :http, plug: Router, options: [port: 3000]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc """
  Crawls a web page. Attempts to find and follow any internal links found on the page up to a specified max depth.

  ## Options

    - output: Output format. Can be one of
      - `:dot` (Writes a DOT file called 'out.dot' in the project root which can be read by visualisers like Graphviz. This is the default. )
      - `:sitemap` (Writes an XML sitemap to a file called 'sitemap.xml' in the project root)
      - `:json` (Writes a summary of the sitemap to a JSON file called 'sitemap.json' in the project root)
      - `:log` (Logs a summary to the console)

    - max_depth: The maximum depth that the crawler should follow page links to. Defaults to `3`.
  """
  def crawl(url, depth \\ 0, opts \\ [])

  def crawl(url, depth, opts) do
    Logger.info("Crawling #{url}")
    max_depth = Keyword.get(opts, :max_depth, @max_depth)
    output_format = Keyword.get(opts, :output, :dot)

    # If depth is zero, then we're at the root of the site. We'll need the root host name
    # later to ensure that we don't follow any external links
    root_host =
      case depth do
        0 ->
          {:ok, root} = url |> URI.parse() |> SiteGraph.reset_state()
          root

        _ ->
          SiteGraph.get_root_host()
      end

    with {:max_depth, depth} when depth <= max_depth <- {:max_depth, depth},
         {:visited_url, false} <-
           {:visited_url, SiteGraph.visited_url?(url)},
         {:ok, page} <- fetch_page(url),
         {:ok, parsed_document} <- Floki.parse_document(page),
         links <- get_links(parsed_document, root_host),
         :ok <- SiteGraph.add_page(url),
         :ok <- SiteGraph.add_links(Enum.map(links, fn link -> Graph.Edge.new(url, link) end)) do
      links
      |> Task.async_stream(fn link -> crawl(link, depth + 1) end, timeout: @timeout)
      |> Stream.run()

      SiteGraph.output(output_format)
    else
      {:visited_url, true} ->
        Logger.info("Already visited #{url}")
        :ok

      {:max_depth, _depth} ->
        Logger.info("Reached max depth for url #{url}")
        :ok

      {:error, error} ->
        Logger.error("Error crawling url #{url}: #{inspect(error)}")
    end
  end

  defp fetch_page(url) do
    with {:cached_page, nil} <- {:cached_page, SiteGraph.retrieve_cached_page(url)},
         {:ok, %HTTPoison.Response{body: body}} <-
           HTTPoison.get(url, [], follow_redirect: true, recv_timeout: @timeout, timeout: @timeout),
         :ok <- SiteGraph.cache_page(url, body) do
      {:ok, body}
    else
      {:cached_page, page} ->
        {:ok, page}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error crawling url #{url}, reason: #{inspect(reason)}")
        {:error, :could_not_fetch_page}
    end
  end

  defp get_links(document, root_host) do
    Floki.attribute(document, "a", "href")
    |> Enum.map(&URI.parse/1)
    |> Enum.map(&URI.merge(root_host, &1))
    |> Enum.filter(fn %URI{host: host, fragment: fragment} ->
      host == root_host.host && is_nil(fragment)
    end)
    |> Enum.map(&URI.to_string/1)
    |> Enum.uniq()
  end
end
