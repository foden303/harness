Add a `getOrSet(key, factory, ttl?)` method to TTLCache.
The interface definition is in `types.ts`.
If the key exists, it returns that value; otherwise it calls the factory function, sets the result, and then returns it.
The factory must also support asynchronous functions.
