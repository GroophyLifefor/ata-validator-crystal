# Builds the ata-validator native library and copies it into libata/.
#
# Usage:
#   crystal run scripts/build_native.cr
#
# Prerequisites: CMake >= 3.28 and a C++20 compiler (VS/Clang/GCC).
# On Windows, cmake auto-detects the Visual Studio generator if MSVC is installed.
#
# Location of the ata-validator source:
#   ATA_VALIDATOR_SRC env var, or ../../ata-validator by default

require "file_utils"

source = ENV["ATA_VALIDATOR_SRC"]? || File.expand_path("../../ata-validator", __DIR__)
build_dir = File.join(source, "build-shared")
lib_dir = File.expand_path("../libata", __DIR__)

abort "error: ata-validator source not found: #{source}" unless Dir.exists?(source)
Dir.mkdir_p(lib_dir)

puts "→ cmake configure (#{source})"
status = Process.run("cmake", ["-B", build_dir, "-DCMAKE_BUILD_TYPE=Release",
                               "-DATA_SHARED=ON", "-DATA_TESTING=OFF"],
                     chdir: source, output: STDOUT, error: STDERR)
exit 1 unless status.success?

puts "→ cmake build (--target ata)"
status = Process.run("cmake", ["--build", build_dir, "--config", "Release", "--target", "ata"],
                     chdir: source, output: STDOUT, error: STDERR)
exit 1 unless status.success?

artifact = {% if flag?(:windows) %}
             File.join(build_dir, "Release", "ata.dll")
           {% elsif flag?(:darwin) %}
             File.join(build_dir, "libata.dylib")
           {% else %}
             File.join(build_dir, "libata.so")
           {% end %}

import = {% if flag?(:windows) %}
           File.join(build_dir, "Release", "ata.lib")
         {% elsif flag?(:darwin) %}
           nil
         {% else %}
           nil
         {% end %}

abort "error: build artifact not found: #{artifact}" unless File.exists?(artifact)

dest = File.join(lib_dir, File.basename(artifact))
File.copy(artifact, dest)
puts "→ copied: #{dest}"

if import && File.exists?(import)
  dest_lib = File.join(lib_dir, File.basename(import))
  File.copy(import, dest_lib)
  puts "→ copied: #{dest_lib}"
end

puts "✓ native library ready"
