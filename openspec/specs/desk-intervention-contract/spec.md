# desk-intervention-contract Specification

## Purpose

Define the on-disk JSON contract between Hermes (writer) and MalDaze (consumer) for timed strong interventions.
## Requirements
### Requirement: Intervention request file path and ownership

The system SHALL use `~/.hermes/data/maldaze/intervention_request.json` as the sole pending intervention contract between Hermes and MalDaze. Hermes SHALL be the only writer of the pending file. MalDaze SHALL read and consume the pending file and SHALL NOT write new intervention requests.

#### Scenario: Hermes writes pending request
- **WHEN** Hermes creates or replaces `intervention_request.json` with valid schema fields
- **THEN** the file exists at the fixed path under `data/maldaze/`
- **AND** MalDaze may load it on next watch event or lifecycle trigger

#### Scenario: MalDaze does not publish requests
- **WHEN** MalDaze handles user local countdown or bell UI
- **THEN** MalDaze does not write `intervention_request.json`
- **AND** local user actions remain independent of the contract

### Requirement: Intervention request schema version one

The pending intervention contract SHALL include `schemaVersion`, `id`, `kind`, `title`, and `requestedAt` as required fields. `schemaVersion` SHALL equal `1`. `kind` SHALL be one of `countdown`, `bell`, or `cancel`. When `kind` is `countdown`, `minutes` SHALL be a positive integer.

#### Scenario: Valid countdown payload
- **WHEN** the pending file contains `schemaVersion: 1`, `kind: "countdown"`, `minutes: 30`, and a UUID `id`
- **THEN** MalDaze treats the payload as executable
- **AND** Hermes considers the write successful

#### Scenario: Missing required field
- **WHEN** the pending file omits any required field
- **THEN** MalDaze fails loud and does not execute partial intervention
- **AND** MalDaze surfaces a diagnosable error state

### Requirement: Consumption and idempotency

MalDaze SHALL acknowledge consumption of a successfully handled request so the same `id` is not executed twice. Consumed records SHALL be retained under `~/.hermes/data/maldaze/consumed/` or an equivalent documented ack mechanism.

#### Scenario: First consumption
- **WHEN** MalDaze executes a valid pending request with id `R1`
- **THEN** MalDaze moves or marks the request as consumed
- **AND** the pending file no longer triggers re-execution

#### Scenario: Duplicate id after consumption
- **WHEN** a consumed record for id `R1` already exists
- **THEN** MalDaze ignores a stale pending file with the same id
- **AND** no second countdown or bell is started

### Requirement: Hermes refuses write when MalDaze is not running

Hermes SHALL detect whether the MalDaze application process is running before writing a pending intervention request. When MalDaze is not running, Hermes SHALL fail loud with a user-visible Feishu error and SHALL NOT write `intervention_request.json`.

#### Scenario: Desk pet not running
- **WHEN** the user requests a strong reminder intervention from Feishu
- **AND** the MalDaze process is not running
- **THEN** Hermes returns an explicit error telling the user to open MalDaze first
- **AND** no pending intervention file is created

#### Scenario: Desk pet running
- **WHEN** MalDaze is running and the user requests intervention
- **THEN** Hermes may write the pending intervention file after passing local validation

### Requirement: Single pending slot with overwrite

The pending intervention file SHALL represent at most one unconsumed request. A newer valid Hermes write SHALL replace the previous pending request.

#### Scenario: New request replaces pending
- **WHEN** a valid pending request already exists
- **AND** Hermes writes a newer valid intervention request
- **THEN** the pending file contains only the newest request
- **AND** MalDaze eventually executes the newest request according to consumption rules

### Requirement: Optional expiry

When `expiresAt` is present, MalDaze SHALL ignore the request after that instant without executing intervention.

#### Scenario: Expired request ignored
- **WHEN** the pending file includes `expiresAt` in the past
- **THEN** MalDaze does not start countdown or bell
- **AND** MalDaze may ack the expired request as skipped

