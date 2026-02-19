{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  wheel,
  numpy,
  cython,
  stdenv,
}:
buildPythonPackage rec {
  pname = "beets_id3extract";
  version = "0.1.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-b/ddn63ZIBr2B1tlF30miRB8OqBZD+Eu0DHkM+5q9Z8=";
  };

  # Build dependencies
  build-system = [
    setuptools
    wheel
  ];

  # Runtime dependencies
  propagatedBuildInputs = [
  ];

  # do not run tests as they are not included in the PyPI package
  doCheck = false;

  # Skip runtime dependency check — this is a beets plugin loaded inside beets,
  # so its declared deps (beets, mediafile, mutagen) are provided by the host.
  dontCheckRuntimeDeps = true;

  meta = with lib; {
    description = "ID3Extract Plugin for beets";
    homepage = "https://github.com/bcotton/beets-id3extract";
    license = licenses.mit;
    maintainers = []; # Add maintainers if desired
  };
}
