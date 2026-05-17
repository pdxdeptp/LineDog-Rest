## 1. Break-Run Shield Screen Binding

- [ ] 1.1 Add a regression test proving the delayed break-run shield does not use `NSScreen.main` and resolves from the desk pet window frame.
- [ ] 1.2 Implement the break-run shield screen resolver and update `showBreakRunShield()` to create the shield on the running pet's current display, with existing fallback behavior preserved.
- [ ] 1.3 Run targeted tests and OpenSpec validation for `bind-break-run-shield-to-pet-screen`.
