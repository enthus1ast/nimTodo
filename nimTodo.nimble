# Package

version       = "0.10.0"
author        = "David Krause (enthus1ast)"
description   = "a small, fast, cli todo organizer, written in Nim"
license       = "MIT"
srcDir        = "src"
bin           = @["nimTodo"]


# Dependencies

requires "nim >= 2.0.0"
requires "cligen" # for commandline cli
requires "sim" # for config parsing


task buildRelease, "builds a release build":
  exec "nim c -d:release -d:danger --opt:speed -d:lto --passl:-s src/nimTodo.nim"

task buildReleaseNative, "builds a release build":
  exec "nim c -d:release -d:danger --opt:speed -d:lto --passl:-s --passc:-march=native src/nimTodo.nim"
