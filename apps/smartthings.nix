{ lib
, buildNpmPackage
, fetchFromGitHub
, installShellFiles
, testers
}:

buildNpmPackage rec {
  pname = "smartthings";
  version = "1.6.0";

  src = fetchFromGitHub {
    owner = "SmartThingsCommunity";
    repo = "smartthings-cli";
    rev = "@smartthings/cli@${version}";
    hash = "sha256-8Eotm5S7Za0zi7pVUVtIBAxCW9atKp71rSwGR4QgiOQ=";
  };

  npmDepsHash = "sha256-2+hVg/sOF69LQvxH1BynKeH2DaRt0la3Na+wBuZVhMk=";
 
  #dontBuild = true;

  #nativeBuildInputs = [ installShellFiles ];

  #postInstall = ''
  #  installShellCompletion --cmd triton --bash <($out/bin/triton completion)
  #  # Strip timestamp from generated bash completion
  #  sed -i '/Bash completion generated.*/d' $out/share/bash-completion/completions/triton.bash
  #'';

  #passthru = {
  #  tests.version = testers.testVersion {
  #  };
  #};

  meta = with lib; {
    description = "The SmartThings CLI is a tool to help with developing SmartApps and drivers for the SmartThings ecosystem.";
    homepage = "https://github.com/SmartThingsCommunity/smartthings-cli";
    license = licenses.asl20;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
