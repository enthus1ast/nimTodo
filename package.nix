{ lib, stdenv, fetchFromGitHub, nim, gcc }:

let
  cligenPkg = fetchFromGitHub {
    owner = "c-blake";
    repo = "cligen";
    rev = "1.11.0";
    sha256 = "sha256-8xCCqNFu1eTQMV+VLLvTOkM1jJc2tBi4+dw1UwwjItE=";
  };
  simPkg = fetchFromGitHub {
    owner = "ba0f3";
    repo = "sim.nim";
    rev = "0.2.2";
    sha256 = "sha256-oIwtIdDJmdcSDHlQenRfQIhF6oXo3pKcUj91vWnti4c=";
  };

in
stdenv.mkDerivation rec {
  pname = "nimTodo";
  version = "0.18.0";

  src = ./.;

  nativeBuildInputs = [ nim gcc ];

  # Copy deps into a writable .nimble/ dir in the build area
  # preBuild runs after unpackPhase; for local dir sources we use
  # configurePhase which runs in the writable copy
  # Copy deps and set writable cache dirs
  preConfigure = ''
    rm -f src/nimTodo src/nimTodo.clang
    mkdir -p .nimble/pkgs
    cp -r ${cligenPkg}/* .nimble/pkgs/
    cp -r ${simPkg}/src/* .nimble/pkgs/
  '';

  # Writable cache dirs for nim compiler
  NIM_CACHE_DIR = "${placeholder "out"}/.nimcache";
  HOME = "${placeholder "out"}";

  buildPhase = ''
    nim c \
      --noNimblePath \
      -d:release -d:danger --opt:speed -d:lto --passl:-s \
      -p:$PWD/.nimble/pkgs \
      src/nimTodo.nim
  '';

  installPhase = ''
    install -Dm755 src/nimTodo $out/bin/nimTodo
  '';

  meta = {
    description = "A small, fast CLI todo organizer written in Nim";
    homepage = "https://github.com/enthus1ast/nimTodo";
    license = lib.licenses.mit;
    maintainers = [ "David Krause" ];
    platforms = [ "x86_64-linux" ];
  };
}
