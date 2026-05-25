# Scope Dependency Check Evidence Schema

Write one file per change:

`openspec/add-initiate-implementation-control/evidence/scope-dependency/<change>.md`

Required fields:

- Timestamp
- Change
- Current change artifacts read
- Upstream change artifacts read
- Downstream change artifacts read
- In-scope responsibilities
- Out-of-scope responsibilities
- Required upstream contracts
- Downstream contracts preserved
- Deferred dependencies
- Validation commands and results
- Result
- Next checkpoint

The matching manifest entry kind is `scope_dependency_check`.
