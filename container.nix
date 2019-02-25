{ ver ? null }:
let

#######################
# Configuration       #
#######################

buildInfo = {
	packages = [
  ];
  # Ensure that any pkgs called / referenced in 'config' are specifically declared in the packages for layered-image to keep last layer minimal
  config = {
		Env = [ "NODE_PATH=/node_modules"
						"NODE_ENV=production"
					];
    # Cmd must be specified as Nix strips any prior definition out to ensure clean execution
		Cmd = [
			"${nodejs}/bin/npm"
			"start"
		];
		WorkingDir = "/";
  };
  name = imageData.name;
  tag = "${imageData.tag}-basal";
};

# Production should contain only the essentials to run the application in a container.
#nodeModules		= (import ../container ({ inherit (pkgs); inherit (nodejs); }));
additonalPackages	= [ pkgs.tini ];
# extend path with additional locations if necessary
path					= "PATH=/usr/bin:/bin";

#######################
# Custom NIX Packages #
#######################

# placeholder

#######################
# Build Image Code    #
#######################

imageData = (builtins.fromJSON (builtins.readFile "${configPath}/image.json"));
configPath = builtins.toPath (builtins.getEnv "PWD") + "/../.nixconfig";

pkgs = import <nixpkgs> {
  overlays = [ (self: super: {
    # Allow unstable libraries if newer versions are of software are needed
    unstable = import (
      fetchTarball https://github.com/NixOS/nixpkgs-channels/archive/nixos-unstable.tar.gz
      ) { config = { allowUnfree = true; }; };
    }
  ) ];
};

in
	# TODO switch to buildLayeredImage to optimize caching, requires merging the two images
	# https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/default.nix contains all available attributes.
	pkgs.unstable.dockerTools.buildImage {
		name = buildInfo.name;
		tag = buildInfo.tag;
		fromImage = if ver == null then "sotekton/basal:nodejs" else "sotekton/basal:nodejs${ver}";
		contents = additonalPackages;
		# Nix is building the container in a workspace, links should always be ./ which will result in / in the final container
		/*
		extraCommands = ''
		'';
		*/
		config = ({
			# Don't override S6 from upstream image as process 0 manager
			Entrypoint = [ "/init" ];
		} // buildInfo.config // { Env = buildInfo.config.Env ++ [ path ]; });
	}
