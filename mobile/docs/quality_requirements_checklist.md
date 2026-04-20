# TikiZaya Quality and Security Checklist

## Security Features

- [x] Protected APIs via token auth middleware in backend
- [x] Basic role field management (currently user-only flow)
- [~] Abuse report system in UI (action exists; backend persistence required)
- [~] Content report in UI (action exists; backend persistence and moderation queue required)
- [x] Privacy settings endpoint and toggle support

## Performance Requirements

- [x] Fast loading baseline with paginated reels feed
- [x] Smooth scrolling baseline with PageView vertical feed
- [x] Responsive UI updates for reel controls on different device sizes
- [x] Mobile-optimized layout for home reel view
- [~] Error handling exists in major flows; standardization still required

## Architecture Requirements

- [~] Clean architecture not fully formalized yet
- [ ] Introduce clear layers: presentation, domain, data
- [ ] Introduce centralized error model and API result wrappers
- [ ] Add repository interfaces and dependency injection boundaries
- [ ] Add automated tests for auth, feed, and moderation/report flows

## Immediate Next Tasks

1. Implement backend report APIs and store reports in DB.
2. Connect reel report action to backend API.
3. Add moderation queue screen (or admin tooling endpoint if needed).
4. Add integration tests for protected endpoints and privacy settings.
5. Standardize error messages and retry handling in API service.
