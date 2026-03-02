module Site exposing (config)

import BackendTask exposing (BackendTask)
import FatalError exposing (FatalError)
import Head
import SiteConfig exposing (SiteConfig)
import SiteMeta


config : SiteConfig
config =
    { canonicalUrl = "https://elm-pages.com"
    , head = head
    }


head : BackendTask FatalError (List Head.Tag)
head =
    SiteMeta.task
        |> BackendTask.map
            (\meta ->
                [ Head.metaName "viewport" (Head.raw "width=device-width,initial-scale=1")
                , Head.sitemapLink "/sitemap.xml"
                , Head.metaName "build-sha" (Head.raw meta.buildSha)
                , Head.metaName "build-timestamp" (Head.raw meta.buildTimestamp)
                , Head.metaName "build-run-id" (Head.raw meta.runId)
                ]
            )
