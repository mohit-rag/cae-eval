The unified search service has a stub implementation that just returns a placeholder instead of actual results with structured fields (kind, uid, name, url, tags, location) matching the existing search frame pattern. When something goes wrong during search, like parsing failures or unexpected data, there's no visibility into what happened. Failures are silent - there's no error logging, and debugging is frustrating.

The frontend also lacks integration with this search API. When the unifiedStorageSearch feature toggle is enabled, there's no way to actually use unified search from the UI. The frontend needs to handle edge cases gracefully, like when the backend can't serve requests.

Fix the backend stub to return actual search results, and improve the debuggability of this search flow so that failures are visible and diagnosable across both the backend and frontend. Don't break existing search functionality.

I've already taken care of all changes to the test files. This means you DON'T have to modify the testing logic or any of the tests in any way!

Your task is to make the minimal changes to non-tests files in the working directory to ensure the task is satisfied.

Use the below interface:

- Path: pkg/services/unifiedSearch/service.go
- Name: customMeta
- Type: struct
- Input: NA
- Output: NA
- Description: Metadata struct for search results frame. Fields: Count (uint64, json:"count"), MaxScore (float64, json:"max_score,omitempty"), SortBy (string, json:"sortBy,omitempty").

- Path: pkg/services/unifiedSearch/service.go
- Name: DashboardListDoc
- Type: struct
- Input: NA
- Output: NA
- Description: Struct representing a dashboard document returned from unified storage search. Fields: UID (string, json:"Uid"), Group (string, json:"Group"), Namespace (string, json:"Namespace"), Kind (string, json:"Kind"), Name (string, json:"Name"), CreatedAt (time.Time, json:"CreatedAt"), CreatedBy (string, json:"CreatedBy"), UpdatedAt (time.Time, json:"UpdatedAt"), UpdatedBy (string, json:"UpdatedBy"), FolderID (string, json:"FolderId"), Spec (anonymous struct with Title string, json:"title", json:"Spec").

- Path: pkg/services/unifiedSearch/service.go
- Name: getDoc
- Type: function
- Input: data []byte
- Output: *DashboardListDoc, error
- Description: Unmarshals a JSON byte slice into a DashboardListDoc. Returns the parsed document or an error if JSON unmarshalling fails.

- Path: public/app/features/search/service/unified.ts
- Name: UnifiedSearcher
- Type: class
- Input: fallbackSearcher: GrafanaSearcher
- Output: NA
- Description: Search service that queries the unified search API endpoint (api/unified-search). Implements the GrafanaSearcher interface. Falls back to the provided fallbackSearcher when the backend returns a frame named "Loading" (indicating index rebuild). Constructor takes a fallbackSearcher of type GrafanaSearcher.

- Path: public/app/features/search/service/unified.ts
- Name: UnifiedSearcher.search
- Type: method
- Input: query: SearchQuery
- Output: Promise<QueryResponse>
- Description: Performs a search query. Throws an error with message "facets not supported!" if query.facet has entries. Otherwise delegates to doSearchQuery.

- Path: public/app/features/search/service/unified.ts
- Name: UnifiedSearcher.starred
- Type: method
- Input: query: SearchQuery
- Output: Promise<QueryResponse>
- Description: Retrieves starred dashboards. Throws error if facets are requested. Fetches starred UIDs from api/user/stars, then searches with those UIDs. Returns empty response (totalRows: 0, isItemLoaded always true) when no stars exist. Uses default query "*" when query.query is undefined.

- Path: public/app/features/search/service/unified.ts
- Name: UnifiedSearcher.tags
- Type: method
- Input: query: SearchQuery
- Output: Promise<TermCount[]>
- Description: Retrieves tag facet counts by posting to api/unified-search with facet [{field: 'tag'}] and limit 1. Falls back to fallbackSearcher.tags when a Loading frame is returned. Returns empty array when no tag frame is found in the response.

- Path: public/app/features/search/service/unified.ts
- Name: UnifiedSearcher.getSortOptions
- Type: method
- Input: NA
- Output: Promise<SelectableValue[]>
- Description: Returns available sort options. Always includes Alphabetically A-Z (name_sort) and Z-A (-name_sort). When config.licenseInfo.enabledFeatures.analytics is true, adds sort fields (views_total, views_last_30_days, errors_total, errors_last_30_days with most/least labels) and time sort fields (created_at, updated_at with recent/oldest labels).

- Path: public/app/features/search/service/unified.ts
- Name: UnifiedSearcher.doSearchQuery
- Type: method
- Input: query: SearchQuery
- Output: Promise<QueryResponse>
- Description: Core search implementation. Posts to api/unified-search, defaulting query to "*" and limit to 50. Falls back to fallbackSearcher.search when a Loading frame is returned. Supports pagination via loadMoreItems (fetches pages of 100) and isItemLoaded.

- Path: public/app/features/search/service/unified.ts
- Name: UnifiedSearcher.getFolderViewSort
- Type: method
- Input: NA
- Output: string
- Description: Returns the sort field used for folder view. Always returns "name_sort".

- Path: public/app/features/search/service/searcher.ts
- Name: getGrafanaSearcher
- Type: function
- Input: NA
- Output: GrafanaSearcher
- Description: Factory function that returns the appropriate GrafanaSearcher implementation. When panelTitleSearch is enabled and "do-frontend-query" is in the URL, returns a FrontendSearcher (early return). When unifiedStorageSearch feature toggle is enabled, returns a UnifiedSearcher wrapping a SQLSearcher as fallback. Otherwise returns a SQLSearcher.
