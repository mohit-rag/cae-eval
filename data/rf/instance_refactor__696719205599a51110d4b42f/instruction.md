The Help Center chat system has a problem with how it determines which bot to talk to. Currently, the odie-client package reads a single botNameSlug from the OdieAssistantContext and uses that value everywhere, in API paths for fetching conversations, loading individual chats, sending messages, submitting feedback, and choosing the initial welcome message. The OdieAssistantProvider resolves this slug internally by checking the help-center store and falling back to a hardcoded default if nothing is set.

This creates two problems. First, callers like the Help Center entry points have no way to specify a different bot for specific environments such as Commerce Garden. The bot choice is buried inside the provider, so all callers get the same default regardless of context. Second, support interactions already store which bot was used when they were created, but the system ignores that and always uses the context value. If someone started a conversation with one bot and the default later changed, their historical conversations would hit the wrong API endpoints, show the wrong welcome message, and have incorrect query cache keys.

Can you refactor the system so that the bot slug for new conversations is determined by the caller and passed down through the Help Center context and into the odie-client provider, rather than being resolved entirely inside the provider? Each Help Center entry point should be able to choose the appropriate bot based on its environment. The provider's internal fallback should use whatever the caller provided instead of a hardcoded string.

For existing conversations, all the hooks and components that make API calls or display bot-specific content should use the bot_slug that is already stored on the support interaction rather than reading from the context. This includes fetching a single chat, sending messages, submitting feedback, and rendering the initial welcome message. For older interactions that may not have a bot_slug, they should fall back gracefully to the standard default.

The conversation listing hook should also be updated so that instead of querying for a single bot slug from the context, it derives the relevant bot slugs from the actual support interactions and uses those when building the API request. It should only make the request once the interactions are available.

The SupportInteraction type needs a bot_slug field, and the provider props should reflect that the bot slug for new conversations comes from the caller as a required value rather than being optional. Also add a default locale slug to the Help Center config so the environment has an i18n default available.

I've already taken care of all changes to the test files. Do NOT modify any test files or testing logic in any way. Your task is to make the minimal changes to non-test source files only.

Use the below interface for your solution:

- Path: `packages/odie-client/src/context/index.tsx`
- Name: `OdieAssistantProvider`
- Type: function
- Input: `defaultBotNameSlug: OdieAllowedBots` (new required prop replacing the previous optional `botNameSlug` prop)
- Output: `JSX.Element`
- Description: Accepts a default bot slug from the caller. When the help-center store does not have a valid bot slug set, falls back to this caller-provided value instead of a hardcoded default.

- Path: `packages/odie-client/src/data/use-get-odie-conversations.ts`
- Name: `useGetOdieConversations`
- Type: function
- Input: `supportInteractions: SupportInteraction[] = [], enabled: boolean = true`
- Output: `UseQueryResult<OdieConversation[], Error>`
- Description: Retrieves the list of AI-handled conversations. Derives the relevant bot slugs from the provided support interactions and uses them in the API path and query key. Only makes the request when interactions are available.
