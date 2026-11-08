{ stdenv, fetchFromGitHub }:

# ISP / provider detection. Was a core plugin until Matomo 3; since Matomo 4
# it is a marketplace plugin, which cannot be installed into the Nix store
# from the UI, so it is baked into the package (see services/matomo.nix).
stdenv.mkDerivation rec {
  pname = "matomo-plugin-Provider";
  version = "5.1.0";

  src = fetchFromGitHub {
    owner = "matomo-org";
    repo = "plugin-Provider";
    rev = version;
    hash = "sha256-1yDeWhO5DUWVZJlOWEJhMU4hQTWoabb0CfR4bTDVoS8=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/plugins/Provider
    cp -R . $out/share/plugins/Provider/
    runHook postInstall
  '';
}
