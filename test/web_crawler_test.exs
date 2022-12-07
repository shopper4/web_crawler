defmodule WebCrawlerTest do
  use ExUnit.Case
  doctest WebCrawler

  test "Basic test" do
    :ok = WebCrawler.crawl("http://localhost:3000/index.html", 0, output: :json)

    {:ok, json} = File.read("sitemap.json")
    sitemap = Jason.decode!(json)

    # Index page should link to about and contact pages
    index_page =
      Enum.find(sitemap, fn %{"url" => url} -> url == "http://localhost:3000/index.html" end)

    assert Enum.sort(index_page["linked_pages"]) == [
             "http://localhost:3000/about.html",
             "http://localhost:3000/contact.html"
           ]

    # Contact page should link to root page
    contact_page =
      Enum.find(sitemap, fn %{"url" => url} -> url == "http://localhost:3000/contact.html" end)

    assert contact_page["linked_pages"] == ["http://localhost:3000"]

    # About page should link to more about and contact pages
    about_page =
      Enum.find(sitemap, fn %{"url" => url} -> url == "http://localhost:3000/about.html" end)

    assert Enum.sort(about_page["linked_pages"]) == [
             "http://localhost:3000/contact.html",
             "http://localhost:3000/more-about.html"
           ]
  end
end
