#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require 'optparse'
require 'fileutils'
require 'net/http'
require 'timeout'
require 'yaml'
require 'json'
require 'pathname'
require_relative 'test_session'

# ---------------------------------------------------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------------------------------------------------

## Timeout
DEFAULT_TIMEOUT = 3600
EXTRACT_TAR_TIMEOUT_SECS = 600  # 10 minutes — generous; nightlies have seen
                                # rare extract_tar hangs that block forever
                                # without one. Bound the loss to one suite.
SUITE_IDLE_TIMEOUT_SECS  = 3600 # 60 minutes — abort a suite if its remote
                                # stream produces zero output for this long.
                                # Healthy suites stream regularly; persistent
                                # silence indicates a stuck remote that will
                                # otherwise hold the DUT until Jenkins kills.
UPLOAD_TIMEOUT_SECS      = 1800 # 30 minutes — `et upload` of a multi-MB
                                # firmware image. Bounds upload-image hangs
                                # so the reservation can release cleanly.

## POST request config
POST_REQ_REPO_URL   = "https://bitbucket.microchip.com/scm/unge/sw-mesa.git"
POST_REQ_OUT_FILE   = "out.tar"
POST_REQ_CACHE_NAME = File.basename(POST_REQ_REPO_URL, ".git")

## Log configuration (SECTION_HEADER_WIDTH and LOG_WIDTH defined in test_session.rb)
LOG_LABEL_LOCAL      = "[l]"
LOG_LABEL_REMOTE     = "[r]"

## HTTP status codes
HTTP_OK                = 200
HTTP_RUNNING           = 202
HTTP_TOO_MANY_REQUESTS = 429

# ---------------------------------------------------------------------------------------------------------------------
# Formatters
# ---------------------------------------------------------------------------------------------------------------------

def strip_html(body)
    body.gsub(/<[^>]+>/, '')
        .gsub('&amp;', '&').gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"')
        .gsub(/\n{3,}/, "\n\n")
        .each_line.map(&:rstrip).reject { |l| l.strip.empty? }.join("\n")
end

def format_html_error(res)
    title   = res.body[/<title[^>]*>(.*?)<\/title>/im,   1]&.strip
    msg     = res.body[/<\/h1>(.*?)<hr/im,               1]&.gsub(/<[^>]+>/, '')&.strip
    address = res.body[/<address[^>]*>(.*?)<\/address>/im, 1]&.gsub(/<[^>]+>/, '')&.split&.join(' ')&.strip

    fields = []
    fields << "\n Fields extracted from HTML:"
    fields << "  Code:    '#{res.code} #{res.message}'"
    fields << "  Title:   '#{title}'"   if title   && !title.empty?
    fields << "  Body:    '#{msg}'"     if msg     && !msg.empty?
    fields << "  Address: '#{address}'" if address && !address.empty?
    fields << "\n"

    fields.join("\n")
end

# ---------------------------------------------------------------------------------------------------------------------
# Loggers
# ---------------------------------------------------------------------------------------------------------------------

def log_write(label, msg)
    $stdout.write msg.to_s.each_line.flat_map { |l|
        l.chomp.scan(/.{1,#{LOG_WIDTH}}/).map { |chunk| "#{label} #{chunk}\n" }
    }.join
end

def log_remote(msg) = log_write(LOG_LABEL_REMOTE, msg)
def log_local(msg)  = log_write(LOG_LABEL_LOCAL,  msg)

def log_subsection_header(title)
    inner = " Subsection: #{title} "
    left  = (SECTION_HEADER_WIDTH - inner.length) / 2
    right = SECTION_HEADER_WIDTH - inner.length - left
    log_local("-" * left + inner + "-" * right)
end

# ---------------------------------------------------------------------------------------------------------------------
# Runners
# ---------------------------------------------------------------------------------------------------------------------

def post_suite(uri, img, out, system, suite, index, timeout, sha)

    suite_name = File.basename(suite, ".rb")
    name_dir = "#{out}/suites/#{[suite_name, system, index].join("-")}"

    req_data = {
        "sha"        => sha,
        "url"        => POST_REQ_REPO_URL,
        "cmd"        => "dr ./mesa/demo/test/utils/dispatch/run-suite-remote.rb -i #{img} -s #{system} -t #{timeout} -T #{suite} -o #{name_dir}",
        "out"        => POST_REQ_OUT_FILE,
        "cache_name" => POST_REQ_CACHE_NAME,
    }

    log_subsection_header("Post suite")
    loop do
        res = Net::HTTP.post(uri, req_data.to_json)
        msg = "POST #{uri}\n  Request:  #{JSON.pretty_generate(req_data)}\n  Response: #{res.code} #{res.message}"
        log_local(msg)
        if res.code.to_i == HTTP_TOO_MANY_REQUESTS
            log_local("Server busy (#{HTTP_TOO_MANY_REQUESTS}), retrying in 10s...")
            sleep(10)
            next
        end
        raise "#{msg}\n#{format_html_error(res)}" if res.code.to_i >= 400
        break
    end
end

def http_get(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30
    http.open_timeout = 30
    http.get(uri.request_uri)
end

def extract_tar(body, out)
    log_local("Received #{body.bytesize} bytes, extracting into #{out}")
    in_r, in_w = IO.pipe
    pid = Process.spawn("tar -xzf -", :in => in_r, [:out, :err] => "/dev/null")

    # Write the body in a separate thread so the main thread never blocks
    # in pipe write — keeps the timeout poll responsive even when the body
    # is larger than the pipe buffer (~64KB) and tar is slow or stuck.
    writer = Thread.new {
        begin
            in_w.write(body)
        rescue Errno::EPIPE
            # tar died early; ignore
        ensure
            in_w.close rescue nil
        end
    }

    # Polling-based timeout: Timeout.timeout cannot interrupt threads blocked
    # in Process.wait/waitpid (Ruby delivers the exception only when the
    # syscall returns, which is never if the child is hung). WNOHANG + sleep
    # keeps the main thread fully under our control.
    deadline = Time.now + EXTRACT_TAR_TIMEOUT_SECS
    timed_out = false
    loop do
        done_pid, _status = Process.waitpid2(pid, Process::WNOHANG)
        break if done_pid
        if Time.now >= deadline
            timed_out = true
            # Capture forensic state before killing tar.  We don't yet know
            # the root cause of these hangs — disk latency, memory pressure,
            # pipe deadlock, etc.  Dumping kernel wait-state, disk usage,
            # and load average gives the next investigation actual data
            # instead of speculation.
            stack    = (File.read("/proc/#{pid}/stack") rescue "    (unreadable)")
            wchan    = (File.read("/proc/#{pid}/wchan").strip rescue "?")
            loadavg  = (File.read("/proc/loadavg").strip rescue "?")
            log_local("=== extract_tar HANG diagnostic (pid #{pid}) ===")
            log_local("  /proc/#{pid}/stack:")
            log_local(stack)
            log_local("  /proc/#{pid}/status (head):")
            log_local(%x{head -20 /proc/#{pid}/status 2>&1})
            log_local("  /proc/#{pid}/wchan: #{wchan}")
            log_local("  loadavg: #{loadavg}")
            log_local("  meminfo (head):")
            log_local(%x{head -5 /proc/meminfo 2>&1})
            log_local("  df -h /:")
            log_local(%x{df -h / 2>&1})
            log_local("=== end diagnostic ===")
            Process.kill("KILL", pid) rescue nil
            Process.waitpid(pid) rescue nil
            break
        end
        sleep 1
    end

    writer.kill rescue nil
    writer.join rescue nil
    in_r.close rescue nil

    if timed_out
        raise "extract_tar timed out after #{EXTRACT_TAR_TIMEOUT_SECS}s on #{body.bytesize}-byte tar"
    end
    log_local("Extraction complete, output at: #{out}")
end

def run_suites(system, image, out, tests_to_run, timeout)
    topo = YAML.load_file(".mscc-libeasy-topology#{system}.yaml")
    uri  = URI("http://#{topo["easytest_server"]}/run")
    # Caller (typically Jenkins) is responsible for resolving the branch they
    # want to test into a concrete SHA and passing it via --sha. Falls back to
    # the working tree's HEAD for ad-hoc/manual use.
    sha = $options[:sha] || %x{git rev-parse HEAD}.strip
    log_local("Test SHA: #{sha} (#{$options[:sha] ? 'explicit' : 'from HEAD'})")

    tests_to_run.each_with_index do |suite, index|
        post_suite(uri, image, out, system, suite, index, timeout, sha)
        log_subsection_header("Streaming log from remote server")

        t_end       = Time.now + timeout
        last_output = Time.now
        loop do
            raise "Timed out waiting for suite '#{suite}'" if Time.now >= t_end

            # Idle timeout: if the remote stream produces no output for
            # SUITE_IDLE_TIMEOUT_SECS, treat the suite as stuck.  Healthy
            # suites stream regularly; persistent silence is a remote-side
            # hang that would otherwise hold the DUT for the full t_end
            # budget (5h) before Jenkins SIGKILLs the stage.
            if Time.now - last_output > SUITE_IDLE_TIMEOUT_SECS
                raise "Suite '#{suite}' idle for >#{SUITE_IDLE_TIMEOUT_SECS}s — aborting"
            end

            res = http_get(uri)
            case res.code.to_i
            when HTTP_RUNNING
                # Suite is still executing on the remote server
                body = res.body.to_s
                unless body.empty?
                    log_remote(body)
                    last_output = Time.now
                end
                sleep(1) # Avoid hammering the server with back-to-back requests
            when HTTP_OK
                # Suite finished successfully — response body is the result tar
                log_subsection_header("Success - Extracting tar")
                extract_tar(res.body, out)
                break
            else
                raise "Unexpected response:\n#{format_html_error(res)}"
            end
        end
    end
end

# ---------------------------------------------------------------------------------------------------------------------
# Utils
# ---------------------------------------------------------------------------------------------------------------------


def reserve(system, timeout)
    t1    = Time.now
    stale = ".mscc-libeasy-topology#{system}.yaml"
    if File.exist?(stale)
        log_local("Removing stale topology file: #{stale}")
        FileUtils.rm(stale)
    end
    loop do
        begin
            run_cmd("et -l -n #{system} reserve #{system}", system)
            return true
        rescue => e
            log_local("Reserve attempt failed: #{e.message}")
        end

        if (Time.now - t1) > timeout
            log_local("Reserve time-out after #{timeout} seconds")
            return false
        end

        log_local("Reserve failed, will try again (#{Time.now - t1} < #{timeout})")
        sleep(30)
    end
end

def upload_image(system, image)
    raise "Image not found: #{image}" unless File.file?(image)
    run_cmd("et -l -n #{system} upload #{image}", system, timeout: UPLOAD_TIMEOUT_SECS)
end

# ---------------------------------------------------------------------------------------------------------------------
# Options parser
# ---------------------------------------------------------------------------------------------------------------------

$options = {
    :tests_to_run => [],
    :out          => ".",
    :timeout      => DEFAULT_TIMEOUT
}

OptionParser.new do |opts|
    opts.banner = "Usage: run-suites-on.rb [options]"
    opts.on("-h", "--help", "This message") { puts opts; exit }
    opts.on("-i", "--image image",   "Image path")                                                              { |v| $options[:image]        = v }
    opts.on("-s", "--system system", "System to reserve")                                                       { |v| $options[:system]       = v }
    opts.on("-t", "--timeout secs",  "Timeout in seconds (default: #{DEFAULT_TIMEOUT})")                        { |v| $options[:timeout]      = v.to_i }
    opts.on("-T", "--test path",     "Test suite to run (repeatable)")                                          { |v| $options[:tests_to_run] << v }
    opts.on("-o", "--output folder", "Session output folder (created by caller, suites written to <out>/suites/)") { |v| $options[:out] = File.expand_path(v); FileUtils.mkdir_p($options[:out]) }
    opts.on("-S", "--sha sha",      "Exact commit SHA the remote server should check out (default: working tree HEAD)") { |v| $options[:sha] = v }
end.parse!

# ---------------------------------------------------------------------------------------------------------------------
# Main sequence
# ---------------------------------------------------------------------------------------------------------------------

if $options[:system]

    log_section_header("Prerequisites")
    top = %x{git rev-parse --show-toplevel}.strip
    Dir.chdir(top)
    $options[:out] = Pathname.new($options[:out]).relative_path_from(Dir.pwd).to_s
    log_local("Output folder: #{$options[:out]}")
    # Version stamp — disambiguates which copy of run-suites-on.rb is running
    # when investigating nightly hangs (e.g. when stale branches and fresh
    # checkouts are in play, or when timeouts unexpectedly don't fire).
    log_local("Script: #{__FILE__}")
    log_local("Script SHA: #{%x{git log -1 --format=%H -- #{__FILE__} 2>/dev/null}.strip}")
    log_local("extract_tar at: #{method(:extract_tar).source_location.join(':')}")

    reserved = false
    begin
        log_section_header("Reserve")
        if !reserve($options[:system], $options[:timeout])
            log_local("Reserve timed out")
            exit 7
        end
        reserved = true
        log_local("Reservation successful")

        log_section_header("Upload image")
        upload_image($options[:system], $options[:image])

        log_section_header("Running test suites")
        log_local("Start time: #{Time.now}")
        run_suites($options[:system], $options[:image], $options[:out], $options[:tests_to_run], $options[:timeout])

    rescue => e
        log_section_header("Test fail summary")
        print_err(e)
        exit 1

    ensure
        if reserved
            begin
                log_section_header("Release")
                run_cmd("et -l -n #{$options[:system]} release", $options[:system])
                log_local("Completed Release")
            rescue
            end
        end
        log_local("End time: #{Time.now}")
    end
end
