{ lib
, fetchFromGitHub
, buildGoModule
, git
, nodejs
, protobuf
, protoc-gen-go
, protoc-gen-go-grpc
, rustPlatform
, pkg-config
, openssl
, extra-cmake-modules
, fontconfig
, go
, testers
, turbo
}:
let
  version = "1.8.8";
  src = fetchFromGitHub {
    owner = "vercel";
    repo = "turbo";
    rev = "v${version}";
    sha256 = "sha256-Qn1qAdhzQrkdMbZs9zqZA0k7UTig39ljJ3DQn49pJf8=";
  };

  go-turbo = buildGoModule rec {
    inherit src version;
    pname = "go-turbo";
    modRoot = "cli";

    vendorSha256 = "sha256-/C5zUQk8bJPBu1L9RYJh74haGkB+37fWldeg/2U8X9I=";

    nativeBuildInputs = [
      git
      nodejs
      protobuf
      protoc-gen-go
      protoc-gen-go-grpc
    ];

    preBuild = ''
      make compile-protos
    '';

    preCheck = ''
      # Some tests try to run mkdir $HOME
      HOME=$TMP

      # Test_getTraversePath requires that source is a git repo
      # pwd: /build/source/cli
      pushd ..
      git config --global init.defaultBranch main
      git init
      popd
    '';

  };
in
rustPlatform.buildRustPackage rec {
  pname = "turbo";
  inherit src version;
  cargoBuildFlags = [
    "--package"
    "turbo"
  ];
  RELEASE_TURBO_CLI = "true";

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "update-informer-0.6.0" = "sha256-uMp6PE4ccNGflbYz5WbLBKDtTlXNjOPA3vAnIMSdMEs=";
    };
  };
  RUSTC_BOOTSTRAP = 1;
  nativeBuildInputs = [
    pkg-config
    extra-cmake-modules
    protobuf
  ];
  buildInputs = [
    openssl
    fontconfig
  ];

  postInstall = ''
    ln -s ${go-turbo}/bin/turbo $out/bin/go-turbo
  '';

  # Browser tests time out with chromium and google-chrome
  doCheck = false;

  passthru.tests.version = testers.testVersion { package = turbo; };

  meta = with lib; {
    description = "High-performance build system for JavaScript and TypeScript codebases";
    homepage = "https://turbo.build/";
    maintainers = with maintainers; [ dlip ];
    license = licenses.mpl20;
  };
}
