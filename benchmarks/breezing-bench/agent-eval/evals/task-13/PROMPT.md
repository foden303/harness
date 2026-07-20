Add a `parseSetCookie(header: string)` function to the HTTP header parser.
The type definition is in `types.ts`.
It parses a Set-Cookie header string and returns the name, value, and attributes (expires, max-age, path, domain, secure, httponly, samesite).
