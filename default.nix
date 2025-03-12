{
  stdenv,
  c3c,
}:
stdenv.mkDerivation rec {
  pname = "c3calc";
  version = "1.0.0";
  src = ./.;

  buildInputs = [
    c3c
  ];

  buildPhase = # sh
    ''
      c3c build
    '';
  installPhase = # sh
    ''
      mkdir -p $out/bin
      cp build/${pname} $out/bin
    '';
}
