The plugin mutation factories in `packages/api-queries/src/site-plugins.ts` always invalidate plugin queries on success. This works fine for most call sites, but the bulk delete flow in `client/dashboard/plugins/plugin/sites-with-this-plugin.tsx` needs to suppress that invalidation for intermediate steps. Currently the delete modal works around this by spreading the mutation options and overriding `onSuccess` with an empty callback, which is fragile and unclear.

Can you refactor the deactivate, autoupdate disable, and remove mutation factories so they natively support opting out of query invalidation? The default behavior should stay the same for all existing callers. Once the factories support this, clean up the delete modal so it uses them directly without needing to spread and override anything.

Also, the `mutateAsync` variable from the update mutation in the same component should be given a more specific alias, since the component has several mutations and the generic name is confusing.

I've already taken care of all changes to the test files. Do NOT modify any test files or testing logic in any way. Your task is to make the minimal changes to non-test source files only.

Use the below interface for your solution:

- Path: `packages/api-queries/src/site-plugins.ts`
- Name: `sitePluginDeactivateMutation`
- Type: function
- Input: `invalidateQueriesOnSuccess: boolean = true`
- Output: `MutationOptions`
- Description: Returns mutation options for deactivating a site plugin. When invalidateQueriesOnSuccess is true (default), invalidates plugin queries on success. When false, skips invalidation.

- Path: `packages/api-queries/src/site-plugins.ts`
- Name: `sitePluginAutoupdateDisableMutation`
- Type: function
- Input: `invalidateQueriesOnSuccess: boolean = true`
- Output: `MutationOptions`
- Description: Returns mutation options for disabling autoupdate on a site plugin. When invalidateQueriesOnSuccess is true (default), invalidates plugin queries on success. When false, skips invalidation.

- Path: `packages/api-queries/src/site-plugins.ts`
- Name: `sitePluginRemoveMutation`
- Type: function
- Input: `invalidateQueriesOnSuccess: boolean = true`
- Output: `MutationOptions`
- Description: Returns mutation options for removing a site plugin. When invalidateQueriesOnSuccess is true (default), invalidates plugin queries on success. When false, skips invalidation.
