# More Generic Sync utility for when node is not used as the devlopment language
let
	pkgs = import <nixpkgs> {};

	packages = with pkgs;
	[
		pkgs.remarshal
		pkgs.jq
		pkgs.gron
	];

	# Create a project relative config directory for storing all external program information
	rootPath = builtins.toPath (builtins.getEnv "PWD");
	configPath = "${rootPath}/.nixconfig";
	# TODO enhance with direnv to allow multiple cluster / account selection(s)

in
  if pkgs.lib.inNixShell
  then pkgs.mkShell
    { buildInputs = packages;
		shellHook = ''
			FATHOMABLE=$(remarshal -i fathomable.yaml -if yaml -of json | gron)
			VERSION_PATH=$(echo "$FATHOMABLE" | grep -oe "^json.*.*.version")
			VERSION=$(jq '.version' package.json)
			TMP=$(mktemp)
			echo "$FATHOMABLE" | sed 's@'"$VERSION_PATH"'.*@'"$VERSION_PATH"' = '"$VERSION"';@' | gron -u > $TMP
			remarshal -i $TMP -if json -o fathomable.yaml -of yaml
			#  $(bashrc)
      '';
    }
  else packages

