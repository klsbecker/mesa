# Copyright (c) 2004-2026 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

# Dispatch — Remote Test Execution

This directory contains the tooling for dispatching test suite execution to a
remote test PC located close to the DUT, collecting results, and generating a
combined Allure report.

```
dispatch/
├── README.md                ← this file
├── test_session.rb          ← shared constants and utilities (logging, run_cmd, print_err)
├── test-config.yaml         ← systems list and nightly/basic suite definitions
├── ssh_known_hosts          ← known host key for the report publishing server
├── run-suites-on.rb         ← LOCAL:  reserves system, dispatches suites, collects result tars
├── run-suite-remote.rb      ← REMOTE: invoked on the test server; runs one suite, tars results
└── generate-report.rb       ← LOCAL:  merges ET.xml files, generates Allure report, publishes
```

## Flow

```
do_dispatch / Jenkinsfile
      │
      ├─► run-suites-on.rb  ──POST──►  easytest server  ──►  run-suite-remote.rb
      │         │                                                    │
      │         │◄──────────── result tar (ET.xml, logs) ───────────┘
      │
      └─► generate-report.rb  ──►  Allure report  ──►  publish server
```

## Entry points

| Script | Where it runs | Called by |
|--------|--------------|-----------|
| `run-suites-on.rb` | Local PC | `do_dispatch`, Jenkinsfile |
| `run-suite-remote.rb` | Remote test server | easytest server |
| `generate-report.rb` | Local PC | `do_dispatch`, Jenkinsfile |

## Configuration

Systems and suites are defined in `test-config.yaml`. Adding a new system or
suite only requires editing that one file — both `do_dispatch` and the
Jenkinsfile pick it up automatically.
