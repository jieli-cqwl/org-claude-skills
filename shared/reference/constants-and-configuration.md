# Constants And Configuration

Constants and configuration belong to the right owner: secrets stay outside the repository, environment differences are configurable, stable public semantics are shared, and local implementation details stay local.

## Forbidden Values

- Do not hardcode secrets, tokens, passwords, private keys, private certificates, production credentials, or account credentials.
- Do not bypass secret management with string concatenation, default fallbacks, copied test configuration, or sample credentials.
- Do not put environment addresses, ports, accounts, deployment paths, or host-specific paths in business logic.

## Classification And Ownership

| Type | Decision | Owner |
| --- | --- | --- |
| Sensitive configuration | Keys, passwords, tokens, secrets, credentials | Environment variables or secret storage, never committed |
| Environment configuration | Addresses, ports, deployment differences, runtime credentials | Configuration file or environment variable |
| User-visible messages | Text shown to users, shared copy, localization | Existing message or i18n system |
| Business constants | Stable values owned by business rules | Owning domain or concept module |
| Enums and statuses | Finite values used for comparison or workflow | Existing enum/type system or owning domain |

## Layering Decision

- Used only in one file: keep it near that file.
- Shared within one module: place it in the module owner.
- Shared across modules: export it only when the value is a stable public contract.
- Do not import another module's private constants across ownership boundaries; adjust dependency direction or keep duplicated local values when no public contract exists.

## Naming And Splitting

- Global constants need a domain prefix that communicates the public contract.
- Module constants need a module or concept prefix that prevents cross-boundary misuse.
- Prefer enums or literal union types for finite sets; bare strings or numbers are acceptable only for local, stable, low-risk values.
- Split growing constant files by domain, ownership, stability, and dependency direction.
- Promote values to global scope only when the semantics are stable and public.
