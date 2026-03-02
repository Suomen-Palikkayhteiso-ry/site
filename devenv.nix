{ ... }:

let shell = { pkgs, ...}: {
  # https://devenv.sh/languages/
  languages = {
    elm.enable = true;
  };

  # https://devenv.sh/packages/
  packages = [
    pkgs.nodejs
    pkgs.elmPackages.elm-format
    pkgs.elmPackages.elm-review
    pkgs.elmPackages.elm-test
    pkgs.elmPackages.elm-json
  ];

  # elm-pages is typically run via npx or installed via npm.
  # We can create a script to make it easier to run.
  scripts.elm-pages.exec = "npx elm-pages \"$@\"";
};

in {
  profiles.shell.module = {
    imports = [ shell ];
  };
}
