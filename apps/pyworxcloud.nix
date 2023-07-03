{ lib
, buildPythonPackage
, fetchFromGitHub
, certifi
, requests
, charset-normalizer
, idna
, paho-mqtt
, urllib3
}:

buildPythonPackage rec {
  pname = "pyworxcloud";
  version = "v3.1.14";

  src = fetchFromGitHub {
    owner = "MTrab";
    repo = pname;
    rev = version;
    sha256 = "l6SnrdqF+TRwuS69XB8rfhWQQ1EzYQ3AkFrtiT/ZcSc=";
  };

  propagatedBuildInputs = [ requests charset-normalizer idna urllib3 ];

  doCheck = false;

  pythonImportsCheck = [ "pyworxcloud" ];

  meta = with lib; {
    description = "Python module for communicating with Worx Cloud mowers, primarily developed for use with Home Assistant";
    homepage = "https://github.com/MTrab/pyworxcloud";
    license = licenses.gpl30;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
