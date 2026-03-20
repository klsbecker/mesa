# Copyright (c) 2004-2026 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

# Shared utilities for run-suites-on.rb and generate-report.rb.
# These two scripts form a complementary pair:
#   run-suites-on.rb   — reserves a system, runs test suites, collects results
#   generate-report.rb — aggregates results across systems, generates Allure report, publishes
#
# Both require this file for common constants, logging and command execution.

require 'open3'

# ---------------------------------------------------------------------------------------------------------------------
# Shared constants
# ---------------------------------------------------------------------------------------------------------------------

SECTION_HEADER_WIDTH = 70
LOG_WIDTH            = 150

# ---------------------------------------------------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------------------------------------------------

# log_local is intentionally NOT defined here — each script defines it with its
# own label ([l] for run-suites-on.rb, [g] for generate-report.rb) so that log
# output is always identifiable by source.

def log_section_header(title)
    inner = " Section: #{title} "
    left  = (SECTION_HEADER_WIDTH - inner.length) / 2
    right = SECTION_HEADER_WIDTH - inner.length - left
    log_local("\n" + "=" * left + inner + "=" * right)
end

# ---------------------------------------------------------------------------------------------------------------------
# Command execution
# ---------------------------------------------------------------------------------------------------------------------

def run_cmd(cmd, label = nil)
    log_local("running cmd: '#{cmd}'")
    prefix = label ? "#{label}: " : ""
    begin
        Open3.popen2e(cmd) do |stdin, output, wait_thr|
            stdin.close
            output.each_line { |line| log_local(line.chomp) }
            raise "#{prefix}'#{cmd}' failed" unless wait_thr.value.success?
        end
    rescue Errno::ENOENT => e
        raise "#{prefix}command not found: #{e.message}"
    end
end

def print_err(e)
    msg  = "Traceback (most recent call last):\n"
    e.backtrace.to_enum.with_index.reverse_each do |t, i|
        if i != 0
            msg += "\t #{i}: #{t}\n"
        else
            msg += "#{t}: #{e} (#{e.class})"
        end
    end
    log_local(msg)
end
