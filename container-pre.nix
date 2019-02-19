let
	pkgs = import <nixpkgs> {};

	packages = with pkgs;
	[
		pkgs.gron
		pkgs.jq
		pkgs.yaml2json
	];

	# Create a project relative config directory for storing all external program information
	rootPath = builtins.toPath (builtins.getEnv "PWD");
	configPath = "${rootPath}/.nixconfig";
	# TODO enhance with direnv to allow multiple cluster / account selection(s)

	aws_shell = pkgs.symlinkJoin {
		name = "aws_shell";
		paths = [ pkgs.aws_shell ];
		buildInputs =	[ pkgs.makeWrapper ];
		postBuild = ''
			mkdir -p ${configPath}
			wrapProgram $out/bin/aws-shell \
				--set-default "AWS_CONFIG_FILE=${configPath}/aws-config AWS_SHARED_CREDENTIALS_FILE=${configPath}/aws-credentials"
		'';
	};

in
  if pkgs.lib.inNixShell
  then pkgs.mkShell
    { buildInputs = packages;
		shellHook = ''
			mkdir -p ${configPath}
			yaml2json < ${rootPath}/fathomable.yaml > ${configPath}/fathomable.json
			IMAGE_NAME=$(cat ${configPath}/fathomable.json | gron | head -n 3 | tail -n 1 | cut -d' ' -f1 | cut -d'.' -f2- | sed 's@\.@/@' | sed 's@\[\"@/@' | sed 's@\"\]@@')
			IMAGE_TAG=$(cat ${configPath}/fathomable.json | gron | grep version | cut -d'=' -f2 | cut -d'"' -f2)
			jq -n --arg name $IMAGE_NAME --arg tag $IMAGE_TAG '{"name": $name, "tag": $tag}' > ${configPath}/image.json
      '';
    }
  else packages
