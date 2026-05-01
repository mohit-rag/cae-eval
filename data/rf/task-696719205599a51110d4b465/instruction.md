The `PanelDataSummary` logic in `packages/grafana-data/src/types/panel.ts` is tightly coupled to the `VisualizationSuggestionsBuilder` class. The summary interface is defined in the same file as the builder, and the computation is a private method inside the class. This means any code that just needs a quick summary of panel data, like `PanelDataErrorView`, has to instantiate a full `VisualizationSuggestionsBuilder` even though it has no interest in visualization suggestions.

The summary interface also has a scalability problem. It uses hardcoded properties for specific field types like `numberFieldCount`, `timeFieldCount`, and `stringFieldCount`, along with corresponding boolean flags like `hasNumberField`, `hasTimeField`, and `hasStringField`. If you want to check for a different field type, you would have to add yet another dedicated property.

Can you refactor the data summary into a standalone utility that can be used independently of the builder? The summary should be available as a simple function call that takes dataframes and returns the summary. Any code that currently instantiates a builder just to get the summary should use the new utility directly instead. The function and its interface should be part of the `@grafana/data` public API.

The field type counting should also be generalized so you can query the count or presence of any field type without needing a dedicated property for each one. The existing per-type properties should be preserved for backward compatibility but marked as deprecated.

I've already taken care of all changes to the test files. Do NOT modify any test files or testing logic in any way. Your task is to make the minimal changes to non-test source files only.

Use the below interface for your solution:

- Path: `packages/grafana-data/src/panel/suggestions/getPanelDataSummary.ts`
- Name: `getPanelDataSummary`
- Type: function
- Input: `frames: DataFrame[] = []`
- Output: `PanelDataSummary`
- Description: Summarizes attributes of the given dataframes for features like panel suggestions. Computes row counts, field counts, frame counts, and field type distributions across all provided frames.

- Path: `packages/grafana-data/src/panel/suggestions/getPanelDataSummary.ts`
- Name: `PanelDataSummary`
- Type: interface
- Input: NA
- Output: NA
- Description: Interface describing the summary of panel data. Includes properties like rowCountTotal, rowCountMax, frameCount, fieldCount, hasData, and preferredVisualisationType. Also provides two methods: fieldCountByType(type: FieldType) which returns the number of fields matching the given type, and hasFieldType(type: FieldType) which returns whether any field of the given type exists. Retains deprecated per-type properties (numberFieldCount, timeFieldCount, stringFieldCount, hasNumberField, hasTimeField, hasStringField) for backward compatibility.
