#!/usr/bin/env ruby

# Copyright (c) 2004-2026 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

# Aggregates ET.xml results from a session directory, generates a combined
# Allure report, and optionally publishes it to the web server.
#
# Intended to be called after one or more run-suites-on.rb invocations have
# written their results into the same session directory.
#
# Usage: generate-report.rb -o <session_dir> [options]

require 'open3'
require 'optparse'
require 'pathname'
require_relative 'test_session'

# ---------------------------------------------------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------------------------------------------------

## Log configuration (SECTION_HEADER_WIDTH and LOG_WIDTH defined in test_session.rb)
LOG_LABEL = "[g]"

## Allure configuration
ALLURE_BIN        = "allure"
MERGED_LOG_FILE   = "session_log_merged.log"
ALLURE_XML2ALLURE = "mesa/demo/test/libeasy/xml2allure.rb"

## Publish configuration
PUBLISH_SERVER      = "www-publish@10.150.48.112"
PUBLISH_PROJECT     = "mesa"
PUBLISH_KNOWN_HOSTS = "mesa/demo/test/utils/dispatch/ssh_known_hosts"

# ---------------------------------------------------------------------------------------------------------------------
# Loggers
# ---------------------------------------------------------------------------------------------------------------------

def log_write(msg)
    $stdout.write msg.to_s.each_line.flat_map { |l|
        l.chomp.scan(/.{1,#{LOG_WIDTH}}/).map { |chunk| "#{LOG_LABEL} #{chunk}\n" }
    }.join
end

def log_local(msg) = log_write(msg)

# ---------------------------------------------------------------------------------------------------------------------
# Utils
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------------------------------------------------

def write_session_meta(session_dir, system, image, suites)
    session_name = File.basename(session_dir)
    rows = {
        "System"  => system  || "all systems",
        "Image"   => image   || "multiple",
        "Suites"  => suites.empty? ? "N/A" : suites.join(", "),
        "Branch"  => %x{git rev-parse --abbrev-ref HEAD}.strip,
        "SHA"     => %x{git rev-parse HEAD}.strip,
        "Time"    => Time.now.to_s,
    }
    File.open("#{session_dir}/session_meta.html", "w") do |f|
        f.puts <<~HTML
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <title>Session: #{session_name}</title>
              <style>
                body { font-family: sans-serif; padding: 2em; }
                h1   { font-size: 1.4em; }
                table { border-collapse: collapse; }
                td, th { border: 1px solid #ccc; padding: 6px 12px; text-align: left; }
                th { background: #f0f0f0; }
              </style>
            </head>
            <body>
              <h1>Session: #{session_name}</h1>
              <table>
                <tr><th>Key</th><th>Value</th></tr>
                #{rows.map { |k, v| "<tr><td>#{k}</td><td>#{v}</td></tr>" }.join("\n    ")}
              </table>
            </body>
            </html>
        HTML
    end
end

def suite_log_merge(session_dir, merged_name)
    xml_files = Dir.glob("#{session_dir}/**/*_ET.xml")
    if xml_files.empty?
        log_local("Log merge skipped: no *_ET.xml files found under #{session_dir}")
        return
    end

    File.open(merged_name, "w") do |f|
        f.write("<?xml version=\"1.0\"?>\n<tests>\n")
        xml_files.each do |xml|
            log_local("Merging '#{xml}'...")
            File.foreach(xml) do |line|
                next if line.include?("<?xml")
                f.write(line)
            end
        end
        f.write("\n</tests>\n")
    end
    log_local("Merged #{xml_files.size} ET.xml file(s) into '#{merged_name}'")
end

def run_allure(log_file, session_dir)
    unless File.file?(log_file)
        log_local("Allure skipped: log file not found: #{log_file}")
        return
    end

    allure_bin = %x{which #{ALLURE_BIN} 2>/dev/null}.strip
    raise "Allure binary '#{ALLURE_BIN}' not found in PATH — is allure installed in this container?" if allure_bin.empty?

    allure_logs   = "#{session_dir}/allure/logs"
    allure_report = "#{session_dir}/allure/report"
    allure_url    = "file://#{File.expand_path(allure_report)}"
    cmd = "cat #{log_file} | #{ALLURE_XML2ALLURE}" \
          " -a #{ALLURE_BIN}" \
          " -l #{allure_logs}" \
          " -o #{allure_report}" \
          " -u #{allure_url}" \
          " --flat"
    run_cmd(cmd)

    unless File.directory?(allure_report)
        raise "Allure ran but report directory was not created: #{allure_report}"
    end

    log_local("Allure report generated:")
    log_local("  Input:   #{log_file}")
    log_local("  Logs:    #{allure_logs}")
    log_local("  Report:  #{allure_report}")
    log_local("  URL:     #{allure_url}")
end

def upload_session(session_dir, keyfile = nil, report_only: false)
    build_num  = ENV["BUILD_NUMBER"] || Time.now.strftime("%Y%m%d%H%M%S")
    branch     = ENV["BRANCH_NAME"]  || %x{git rev-parse --abbrev-ref HEAD}.strip
    project    = "#{PUBLISH_PROJECT}/#{branch}"
    session    = File.basename(session_dir)
    upload_dir = report_only ? "#{session_dir}/allure/report" : session_dir

    raise "Allure report not found at #{upload_dir}" unless File.directory?(upload_dir)

    ssh_cmd  = "ssh"
    ssh_cmd += " -i #{keyfile}" if keyfile
    ssh_cmd += " -o \"UserKnownHostsFile #{PUBLISH_KNOWN_HOSTS}\""
    ssh_cmd += " #{PUBLISH_SERVER}"
    ssh_cmd += " ./web-pack-rx -n #{build_num} -b #{session} -J -p #{project}"

    log_local("Creating tar.xz of #{upload_dir} and uploading to #{PUBLISH_SERVER}...")
    log_local("  URL: http://lon-vm-ung-mdi.microchip.com/ci/#{project}/#{session}/")

    # Stream tar output directly to ssh stdin to avoid buffering the entire
    # tarball in memory (large sessions were OOM-killed at this step).
    Open3.popen2e(ssh_cmd) do |ssh_in, ssh_out, ssh_thread|
        # Drain ssh output concurrently to avoid deadlock if the server writes
        # enough to fill the pipe buffer while we are still streaming tar data.
        out_buf = ""
        reader = Thread.new { out_buf = ssh_out.read }

        Open3.popen2("tar", "-cJf", "-", "-C", upload_dir, ".") do |_, tar_out, tar_thread|
            IO.copy_stream(tar_out, ssh_in)
            tar_st = tar_thread.value
            raise "tar failed (exit #{tar_st.exitstatus})" unless tar_st.success?
        end
        ssh_in.close
        reader.join
        ssh_st = ssh_thread.value
        log_local(out_buf) unless out_buf.empty?
        raise "Upload failed (exit #{ssh_st.exitstatus})" unless ssh_st.success?
    end
    log_local("Upload complete")
end

# ---------------------------------------------------------------------------------------------------------------------
# Options parser
# ---------------------------------------------------------------------------------------------------------------------

$options = { suites: [] }

OptionParser.new do |opts|
    opts.banner = "Usage: generate-report.rb -o <session_dir> [options]"
    opts.on("-h", "--help", "This message") { puts opts; exit }
    opts.on("-o", "--output dir",    "Session directory containing suite results") { |v| $options[:session_dir] = v }
    opts.on("--system name",         "System name for metadata (default: 'all systems')")  { |v| $options[:system]  = v }
    opts.on("--image path",          "Image path for metadata (default: 'multiple')")      { |v| $options[:image]   = v }
    opts.on("--suite path",          "Suite name for metadata (repeatable)")                { |v| $options[:suites] << v }
    opts.on("--publish",             "Upload session to web server")                        { $options[:publish]      = true }
    opts.on("--report-only",         "Upload only the Allure report instead of full session") { $options[:report_only] = true }
    opts.on("--keyfile path",        "SSH private key for publishing")                      { |v| $options[:keyfile]  = v }
end.parse!

abort "Error: -o <session_dir> is required" unless $options[:session_dir]

# ---------------------------------------------------------------------------------------------------------------------
# Main sequence
# ---------------------------------------------------------------------------------------------------------------------

top         = %x{git rev-parse --show-toplevel}.strip
session_abs = File.expand_path($options[:session_dir])
Dir.chdir(top)

session_dir = Pathname.new(session_abs).relative_path_from(Dir.pwd).to_s

log_section_header("Session metadata")
write_session_meta(session_dir, $options[:system], $options[:image], $options[:suites])

log_section_header("Merge suite logs")
merged_log = "#{session_dir}/#{MERGED_LOG_FILE}"
suite_log_merge(session_dir, merged_log)

log_section_header("Allure report")
run_allure(merged_log, session_dir)

if $options[:publish]
    log_section_header("Publish session")
    upload_session(session_dir, $options[:keyfile], report_only: $options[:report_only])
end
