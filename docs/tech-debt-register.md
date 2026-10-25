## Technical Debt Register

Last updated: 2026-10-25
Total items: 6 | Estimated total effort: 6 S

| ID | Category | Description | Files | Effort | Impact | Priority | Status | Added | Sprint |
|----|----------|-------------|-------|--------|--------|----------|--------|-------|--------|
| TD-002 | Code Quality | `GameData` validates only top-level config keys; missing `camera` sub-keys or a malformed class `color` crash at runtime — from production/epics/quarantine-breach/story-001-squad-control-and-loadouts.md | src/squads/game_data.gd, src/squads/camera_rig.gd | S | Med | 2.0 | Open | 2026-10-25 | Backlog |
| TD-001 | Code Quality | `retarget_interval` (0.25) and presentation sizes (mesh, ring, label, nav distances) are hardcoded instead of data-driven — from production/epics/quarantine-breach/story-001-squad-control-and-loadouts.md | src/squads/soldier.gd | S | Low | 1.0 | Open | 2026-10-25 | Backlog |
| TD-003 | Code Quality | More than 3 `default_squads` in the config overrun the scene's 3 spawn markers (index out of range) — from production/epics/quarantine-breach/story-001-squad-control-and-loadouts.md | src/squads/greybox_block.gd, src/squads/game_data.gd | S | Low | 1.0 | Open | 2026-10-25 | Backlog |
| TD-004 | Code Quality | A non-mesh node in the `obstacles` group crashes the fog setup (`as MeshInstance3D` not null-checked) — from production/epics/quarantine-breach/story-001-squad-control-and-loadouts.md | src/squads/greybox_block.gd | S | Low | 1.0 | Open | 2026-10-25 | Backlog |
| TD-005 | Code Quality | Shot tracer calls `look_at_from_position` without guarding equal or vertical points, which logs an error — from production/epics/quarantine-breach/story-001-squad-control-and-loadouts.md | src/squads/greybox_block.gd | S | Low | 1.0 | Open | 2026-10-25 | Backlog |
| TD-006 | Code Quality | Squad number keys use `keycode`, so they depend on keyboard layout (use `physical_keycode`) — from production/epics/quarantine-breach/story-001-squad-control-and-loadouts.md | src/squads/selection_controller.gd | S | Low | 1.0 | Open | 2026-10-25 | Backlog |
