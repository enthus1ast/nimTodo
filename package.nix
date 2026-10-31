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

  # Build nimTodo from a proper source tarball (so nix copies to writable dir)
  src = ./.;

in
stdenv.mkDerivation {
  pname = "nimTodo";
  version = "0.18.0";

  # Use src as a tarball by wrapping it
  src = builtins.toFile "nimTodo-src" ./.;

  # Don't try to unpack a regular file as a directory
  # Instead, extract it manually
  unpackPhase = ''
    tar xf $src -C $out --strip-components=1
    cp -r $out/* .
  '';

  nativeBuildInputs = [ nim gcc ];

  preBuild = ''
    rm -f src/nimTodo src/nimTodo.clang
    mkdir -p .nimble/pkgs
    # Copy deps into build dir (writable)
    cp -r ${cligenPkg}/* .nimble/pkgs/
    cp -r ${simPkg}/src/* .nimble/pkgs/
  '';

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
