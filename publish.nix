let
	pkgs = import <nixpkgs> {};

	packages = with pkgs;
	[
		aws_shell

		pkgs.gron
		pkgs.jq
		pkgs.skopeo
		#pkgs.yaml2json
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
			# Available via 'container-pre'
			# yaml2json < fathomable.yaml > ${configPath}/fathomable.json

			set -e
			IMAGE_REGISTRY=$(cat .nixconfig/fathomable.json | gron | grep "domain" | cut -d'=' -f2 | cut -d'"' -f2)

			# ECR Backend
			if $(echo "$IMAGE_REGISTRY" | grep "ecr" -q); then
				LOGIN=$(aws ecr get-login --no-include-email --region ap-southeast-2)
				USERNAME=$(echo $LOGIN | cut -d' ' -f4)
				echo "$USERNAME" > ${configPath}/docker/username
				PASSWORD=$(echo $LOGIN | cut -d' ' -f6)
				echo "$PASSWORD" > ${configPath}/docker/password
				BACKEND="ECR"
				echo "$BACKED" > ${configPath}/docker/backend
			fi

			# Upload
			REPOSITORY="$(cat ${configPath}/docker/name):$(cat ${configPath}/docker/tag)"
			if [ -e "$EXTEND_BASAL" ]; then
				REPOSITORY="$REPOSITORY-basal"
				#REPOSITORY=$(cat $(tar xvf ${rootPath}/container/CONTAINER_TAR.tar.gz manifest.json) | jq -r '.[0].RepoTags[0]')
				#rm -f manifest.json
			fi
			echo "$REPOSITORY" > ${configPath}/docker/repository
			# Create Repository if non-existent
			if [ "$BACKEND" == "ECR" ]; then
				## TODO apply policy to repository
				REPO_NAME=$(echo $REPOSITORY | cut -d':' -f1)
				! $(aws ecr describe-repositories | jq '.repositories[].repositoryName' | grep "$REPO_NAME" -q) && aws ecr create-repository --repository-name $REPO_NAME
			fi

			skopeo copy --dest-creds $USERNAME:$PASSWORD docker-archive://${rootPath}/container/$CONTAINER_TAR.tar.gz docker://$IMAGE_REGISTRY/$REPOSITORY
      '';
    }
  else packages
