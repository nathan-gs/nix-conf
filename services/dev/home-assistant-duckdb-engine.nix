{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pytestCheckHook,
  pythonOlder,
  duckdb,
  hypothesis,
  poetry-core,
  sqlalchemy,
  typing-extensions,
}:

buildPythonPackage rec {
  pname = "duckdb-engine";
  version = "0.12.0";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    repo = "duckdb_engine";
    owner = "Mause";
    rev = "36811f05c7618e56f51aa2a62fe4ab99627dd963";
    hash = "sha256-kSixrGRsi1kuCzQ5SRfz71o9oNKuTeBSfv2yLpOcHGQ=";
  };

  nativeBuildInputs = [ poetry-core ];

  propagatedBuildInputs = [
    duckdb
    sqlalchemy
  ];

  #preCheck = ''
  #  export HOME="$(mktemp -d)"
  #'';

  withoutCheckDeps = true;
  doCheck = false;
  doInstallCheck = false;
  dontCheck = true;
  pytestCheckPhase = false;

  disabledTests = [
    # test should be skipped based on sqlalchemy version but isn't and fails
    "test_commit"
  ];

  #nativeCheckInputs = [ pytestCheckHook ];

  #checkInputs = [
  #  hypothesis
  #  typing-extensions
  #];

  #pytestFlagsArray = [
  #  "-m"
  #  "'not remote_data'"
  #];

  #pythonImportsCheck = [ "duckdb_engine" ];

  meta = with lib; {
    description = "SQLAlchemy driver for duckdb";
    homepage = "https://github.com/Mause/duckdb_engine";
    changelog = "https://github.com/Mause/duckdb_engine/blob/v${version}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [ cpcloud ];
  };
}