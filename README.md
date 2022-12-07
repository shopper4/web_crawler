# WebCrawler

A simple web crawler written by Sam Hopper for a technical interview task.

## Installation

Run `mix deps.get`

## Usage

I've been running this in a REPL - run `iex -S mix run` to start. To crawl a page run `WebCrawler.crawl("https://localhost:3000/index.html")`.

By default the crawler will output a DOT file called `out.dot` in the project root folder. If you have [GraphViz](https://graphviz.org/download/) installed you can generate a sitemap image by running `dot -Tpng out.dot > out.png`.

You can also generate other output formats, details are in the doc comments for the crawl function.

Since this is not a production ready web crawler, and was written in a few hours as an interview task, it struggles a bit with timeouts on large websites. To make it easier to test, I've included a basic test website in the `testsite` directory. The application starts a basic plug_cowboy webserver to serve the files on port 3000.

## Tests

I've added a basic test, you can run using `mix test`
