{ stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "matomo-plugin-McpServer";
  version = "5.1.0";

  src = fetchFromGitHub {
    owner = "matomo-org";
    repo = "plugin-McpServer";
    rev = version;
    hash = "sha256-xEDfwP28OnP3HM2JTcdtd5eppzKNum8ZJGuH/Yb2VBU=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/plugins/McpServer
    cp -R . $out/share/plugins/McpServer/
    runHook postInstall
  '';
}
