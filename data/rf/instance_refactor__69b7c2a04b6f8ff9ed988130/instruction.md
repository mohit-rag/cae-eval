The engine analysis subsystem in src/detect-engine-analyzer.c stores all its state in file-scoped statics and globals: output file handles, compiled PCRE objects, analyzer item tracking, fast pattern statistics, etc. This breaks when multiple DetectEngineCtx instances exist (multi-tenant configurations with config_prefix), since they all share and clobber the same state and write to the same log files.

Refactor this so each DetectEngineCtx owns its own analysis state. Each engine's log files should incorporate its config_prefix so multi-tenant setups produce distinct outputs. The individual setup/cleanup functions currently exposed in src/detect-engine-analyzer.h (SetupFPAnalyzer, CleanupFPAnalyzer, SetupRuleAnalyzer, CleanupRuleAnalyzer, PerCentEncodingSetup, PerCentEncodingMatch) should be internalized behind a unified public setup/cleanup API that takes the DetectEngineCtx. Update the call sites in src/detect-engine-loader.c, src/detect-engine-build.c, and src/detect-flowbits.c accordingly.

While you're in here, fix two existing bugs: CleanupRuleAnalyzer never frees the compiled PCRE objects (percent_re, percent_re_study), and PerCentEncodingMatch takes content_len as uint8_t which silently truncates values over 255. Also add pcre/pcre_extra fields for classification and reference config parsing to DetectEngineCtx\_ in src/detect.h, grouped alongside the existing class_conf_ht and reference_conf_ht hash tables.

I've already taken care of all changes to the test files. Do NOT modify any test files or testing logic in any way. Your task is to make the minimal changes to non-test source files only.

Use the below Interface:

\- Path: src/detect-engine-analyzer.h

  - Name: SetupEngineAnalysis

  - Type: function

  - Input: struct DetectEngineCtx\_ *de_ctx, bool* fp_analysis, bool \*rule_analysis

  - Output: void

  - Description: Unified setup entry point for engine analysis. Allocates an EngineAnalysisCtx\_ on de_ctx-&gt;ea, derives a file prefix from de_ctx-&gt;config_prefix, then calls internal SetupFPAnalyzer and SetupRuleAnalyzer. Writes results into the two output booleans. If neither analyzer is enabled, frees the allocated context. Replaces the previously-public SetupFPAnalyzer and SetupRuleAnalyzer.

  - Name: CleanupEngineAnalysis

  - Type: function

  - Input: struct DetectEngineCtx\_ \*de_ctx

  - Output: void

  - Description: Unified cleanup entry point for engine analysis. If de_ctx-&gt;ea is non-NULL, calls internal CleanupRuleAnalyzer and CleanupFPAnalyzer, frees the compiled PCRE objects (percent_re, percent_re_study), frees file_prefix, frees analyzer_items, frees the EngineAnalysisCtx\_ itself, and sets de_ctx-&gt;ea to NULL. Replaces the previously-public CleanupFPAnalyzer and CleanupRuleAnalyzer.

  - Name: EngineAnalysisRulesFailure

  - Type: function

  - Input: const struct DetectEngineCtx\_ *de_ctx, char* line, char \*file, int lineno

  - Output: void

  - Description: Logs a rule-parsing failure to the engine analysis output file. Modified from the original signature by adding de_ctx as the first parameter so it can access the per-engine analysis file pointer via de_ctx-&gt;ea instead of a file-scoped static.

\- Path: src/detect.h

  - Name: DetectEngineCtx\_

  - Type: struct

  - Input: N/A

  - Output: N/A

  - Description: The class_conf_ht and reference_conf_ht hash table pointers are relocated (from near sc_sig_order_funcs to after sm_types_silent_error). New fields are added grouped with them: pcre class_conf_regex, pcre_extra class_conf_regex_study (for classification config parsing), pcre reference_conf_regex, pcre_extra reference_conf_regex_study (for reference config parsing). A new opaque pointer struct EngineAnalysisCtx\_ \*ea is added for per-engine analysis state.

\- Path: src/detect-engine-loader.c (definition), src/detect-engine-build.c (extern), src/detect-flowbits.c (extern)

  - Name: rule_engine_analysis_set

  - Type: global variable

  - Input: N/A

  - Output: N/A

  - Description: Type changes from int to bool. The corresponding static variable fp_engine_analysis_set in src/detect-engine-loader.c also changes from int to bool. All extern declarations must be updated to match.