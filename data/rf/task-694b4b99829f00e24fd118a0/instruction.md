In gitlab.go, refactor getAllProjects used when --repo is not specified. Keep the same effective set of accessible projects (user projects plus group projects including subgroups), but dedupe projects globally so each project appears only once (by project ID), make the returned project list deterministic given the same API responses, reduce API calls by using the maximum page size (100) on the relevant list endpoints, improve logging so default logs only include a summary count and detailed project names are only logged at higher verbosity, and return contextual, wrapped errors (%w) so failures can be traced upstream.

I've already taken care of all changes to the test files. This means you DON'T have to modify the testing logic or any of the tests in any way!

Your task is to make the minimal changes to non-tests files in the working directory to ensure the task is satisfied.
