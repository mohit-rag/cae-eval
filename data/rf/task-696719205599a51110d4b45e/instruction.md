The alerting rule filtering logic in `public/app/features/alerting/unified/rule-list/hooks/filters.ts` has grown into a monolithic file that handles too many concerns in one place.

Currently, filtering for datasource-managed rules and Grafana-managed rules lives side by side in the same file, even though they have different filtering strategies. Datasource rules apply all filters on the client side, while Grafana rules split filtering between backend and client depending on feature flags. Shared predicate functions for matching rules and groups by name, labels, state, health, type, dashboard UID, contact point, datasource, and plugins are all inlined alongside the filter orchestration logic. Normalization utilities like lowercasing filter state fields and building a combined title search string are also mixed in rather than being separated.

The `hasClientSideFilters` function is particularly fragile. It manually checks each individual filter state property to determine if client-side filtering is needed, which means it can easily fall out of sync when filter configurations change. It should instead derive its answer from the same filter configuration that the actual filtering logic uses, so there is a single source of truth for which filters are client-side vs backend.

Can you refactor this file to improve separation of concerns? The filtering logic for datasource-managed rules and Grafana-managed rules should be cleanly separated into their own modules. The shared filter predicate functions should be extracted so both can reuse them through a configuration-driven approach, where each filter is either an active predicate or null to indicate it is handled elsewhere. The normalization utilities should also be extracted into their own module. The `hasClientSideFilters` function should be refactored to rely on the filter config object so it automatically stays in sync with the actual filter configuration.

I've already taken care of all changes to the test files. Do NOT modify any test files or testing logic in any way. Your task is to make the minimal changes to non-test source files only.

Use the below interface for your solution:

- Path: `public/app/features/alerting/unified/rule-list/hooks/datasourceFilter.ts`
- Name: `getDatasourceFilter`
- Type: function
- Input: `filterState: RulesFilter`
- Output: `{ groupMatches: (group: PromRuleGroupDTO) => boolean, ruleMatches: (rule: PromRuleDTO) => boolean }`
- Description: Builds filter configuration for datasource-managed alert rules where all filters are applied client-side. Normalizes the filter state and returns closures for matching groups and rules.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterNormalization.ts`
- Name: `buildTitleSearch`
- Type: function
- Input: `filterState: RulesFilter`
- Output: `string | undefined`
- Description: Combines ruleName and freeFormWords into a single search string for backend filtering. Trims whitespace and filters empty entries. Returns undefined when no search terms exist.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterNormalization.ts`
- Name: `normalizeFilterState`
- Type: function
- Input: `filterState: RulesFilter`
- Output: `RulesFilter`
- Description: Normalizes filter state for case-insensitive matching by lowercasing freeFormWords, ruleName, groupName, and namespace.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `RuleFilterHandler`
- Type: type
- Input: NA
- Output: NA
- Description: Function signature for rule filter predicates. Takes a PromRuleDTO and RulesFilter, returns boolean.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `GroupFilterHandler`
- Type: type
- Input: NA
- Output: NA
- Description: Function signature for group filter predicates. Takes a PromRuleGroupDTO and the namespace/groupName subset of RulesFilter, returns boolean.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `RuleFilterConfig`
- Type: type
- Input: NA
- Output: NA
- Description: Record mapping each rule filter key (excluding namespace, groupName, ruleSource) to either a RuleFilterHandler or null. Null indicates the filter is handled elsewhere (e.g. backend).

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `GroupFilterConfig`
- Type: type
- Input: NA
- Output: NA
- Description: Record mapping namespace and groupName keys to either a GroupFilterHandler or null.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `groupMatches`
- Type: function
- Input: `group: PromRuleGroupDTO, filterState: Pick<RulesFilter, 'namespace' | 'groupName'>, filterConfig: GroupFilterConfig`
- Output: `boolean`
- Description: Returns true if the group matches all active filters in the config. Skips filters set to null.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `ruleMatches`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter, filterConfig: RuleFilterConfig`
- Output: `boolean`
- Description: Returns true if the rule matches all active filters in the config. Skips filters set to null. Checks each filter with AND logic.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `namespaceFilter`
- Type: function
- Input: `group: PromRuleGroupDTO, filterState: Pick<RulesFilter, 'namespace' | 'groupName'>`
- Output: `boolean`
- Description: Matches group file path against the namespace filter using fuzzy matching.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `groupNameFilter`
- Type: function
- Input: `group: PromRuleGroupDTO, filterState: Pick<RulesFilter, 'namespace' | 'groupName'>`
- Output: `boolean`
- Description: Matches group name against the groupName filter using fuzzy matching.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `freeFormFilter`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter`
- Output: `boolean`
- Description: Matches rule name against joined freeFormWords using fuzzy matching.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `ruleNameFilter`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter`
- Output: `boolean`
- Description: Matches rule name against the ruleName filter using fuzzy matching.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `labelsFilter`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter`
- Output: `boolean`
- Description: Matches rule labels and alert instance labels against label matchers parsed from the filter state.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `ruleTypeFilter`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter`
- Output: `boolean`
- Description: Matches rule type against the ruleType filter.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `ruleStateFilter`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter`
- Output: `boolean`
- Description: Matches alerting rule state against the ruleState filter. Returns false for non-alerting rules when a state filter is active.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `ruleHealthFilter`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter`
- Output: `boolean`
- Description: Matches normalized rule health against the ruleHealth filter.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `contactPointFilter`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter`
- Output: `boolean`
- Description: Matches Grafana alerting rule notification settings receiver against the contactPoint filter.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `dashboardUidFilter`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter`
- Output: `boolean`
- Description: Matches alerting rule dashboard UID annotation against the dashboardUid filter.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `pluginsFilter`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter`
- Output: `boolean`
- Description: Hides plugin-provided rules when the plugins filter is set to hide.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/filterPredicates.ts`
- Name: `dataSourceNamesFilter`
- Type: function
- Input: `rule: PromRuleDTO, filterState: RulesFilter`
- Output: `boolean`
- Description: For Grafana rules, checks if the rule queries any of the filtered datasources by resolving datasource names to UIDs.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/grafanaFilter.ts`
- Name: `hasClientSideFilters`
- Type: function
- Input: `filterState: RulesFilter`
- Output: `boolean`
- Description: Determines if client-side filtering is needed for Grafana-managed rules by checking the filter config for non-null handlers with active filter state values.

---

- Path: `public/app/features/alerting/unified/rule-list/hooks/grafanaFilter.ts`
- Name: `getGrafanaFilter`
- Type: function
- Input: `filterState: RulesFilter`
- Output: `{ backendFilter: GrafanaPromRulesOptions, frontendFilter: { groupMatches: (group: PromRuleGroupDTO) => boolean, ruleMatches: (rule: PromRuleDTO) => boolean } }`
- Description: Builds combined backend and frontend filter configuration for Grafana-managed rules. Backend filter includes state, health, contactPoint, and conditionally title, type, dashboardUid, and groupName based on feature flags. Frontend filter provides client-side matching closures.
