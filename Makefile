.DEFAULT_GOAL := help

.PHONY: help init up status verify failover demo-wal-heartbeat record-wal-heartbeat logs down reset check diagrams check-diagrams

help:
	@printf '%s\n' 'Targets: init up status verify failover demo-wal-heartbeat record-wal-heartbeat logs down reset check diagrams check-diagrams'

init:
	@./scripts/init.sh

up: init
	@./scripts/up.sh

status:
	@./scripts/status.sh

verify: init
	@./scripts/verify.sh

failover:
	@./scripts/failover.sh

demo-wal-heartbeat: init
	@./scripts/demo-wal-heartbeat.sh

record-wal-heartbeat: init
	@./scripts/launch-wal-demo-recording.sh

logs:
	@./scripts/compose.sh logs --tail=200 --follow

down:
	@./scripts/compose.sh down --remove-orphans

reset:
	@./scripts/reset.sh

check: init
	@./scripts/check.sh

diagrams:
	@./scripts/render-diagrams.sh

check-diagrams:
	@./scripts/render-diagrams.sh --check
