The Gradle parser module has some code duplication that needs cleaning up.

The query matchers `qGroupId`, `qArtifactId`, and `qVersion` are defined identically in `dependencies.ts`, `plugins.ts`, and `version-catalogs.ts`. Consolidate these into `common.ts` and have the other files import from there.

Also in `registry-urls.ts`, there's an inline tree query for parsing Maven artifact registry configs that's a bit unwieldy. Extract it into a named constant for better readability.

While you're at it, the `qDotOrBraceExpr` function in `common.ts` has an unnecessary nested `q.alt()` that can be flattened.

I've already taken care of all changes to the test files. This means you DON'T have to modify the testing logic or any of the tests in any way!

Your task is to make the minimal changes to non-tests files in the working directory to ensure the task is satisfied.

Use the below Interface:

\- Path: lib/modules/manager/gradle/parser/common.ts
- Name: `qGroupId`
- Type: const
- Input: NA
- Output: `q.QueryBuilder<Ctx, parser.Node>`
- Description: Query matcher that captures a value and stores it in the token map under the key 'groupId'.

\- Path: `lib/modules/manager/gradle/parser/common.ts`
- Name: `qArtifactId`
- Type: const
- Input: NA
- Output: `q.QueryBuilder<Ctx, parser.Node>`
- Description: Query matcher that captures a value and stores it in the token map under the key 'artifactId'.

\- Path: `lib/modules/manager/gradle/parser/common.ts`
- Name: `qVersion`
- Type: const
- Input: NA
- Output: `q.QueryBuilder<Ctx, parser.Node>`
- Description: Query matcher that captures a value and stores it in the token map under the key 'version'.