Add a `mergeWithStrategy(base, override, strategy)` method to ConfigMerger.
The interface definition is in `types.ts`.
strategy can be 'replace' | 'append' | 'prefer-base', and controls the array merge strategy for nested objects.
