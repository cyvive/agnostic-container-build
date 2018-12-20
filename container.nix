let

#######################
# Configuration       #
#######################

nodejs = pkgs.nodejs-8_x;

buildInfo = {
	packages = [
  ];
  # Ensure that any pkgs called / referenced in 'config' are specifically declared in the packages for layered-image to keep last layer minimal
  config = {
		Env = [ "NODE_PATH=/lib/${nodeModules.modulePath}/${nodeModules.basicName}/node_modules"
						"NODE_ENV=production"
					];
    # Cmd must be specified as Nix strips any prior definition out to ensure clean execution
		Cmd = [
			"${nodejs}/bin/npm"
			"start"
		];
		WorkingDir = "/lib/${nodeModules.modulePath}/${nodeModules.basicName}";
  };
  name = "layered-on-top";
  tag = "latest";
};

# Production should contain only the essentials to run the application in a container.
imagePackages				= [ pkgs.coreutils pkgs.tini ];
pathProd						= "PATH=${pkgs.coreutils}/bin/:${nodejs}/bin/";
# Debug should contain the additional tooling for interactivity and debugging, doesn't necessarily pull in the applications 'Development' mode and libraries
imagePackagesDebug  = [ pkgs.bash ];
pathDebug						= "${pathProd}:${pkgs.bash}/bin/";

#######################
# Build Image Code    #
#######################

pkgs = import <nixpkgs> {
  overlays = [ (self: super: {
    # Allow unstable libraries if newer versions are of software are needed
    unstable = import (
      fetchTarball https://github.com/NixOS/nixpkgs-channels/archive/nixos-unstable.tar.gz
      ) { config = { allowUnfree = true; }; };
    }
  ) ];
};

nodeModules = (import ../container ({ inherit (pkgs); inherit (nodejs); }));
in
	rec {
		prod = let
			transient-layers = pkgs.unstable.dockerTools.buildLayeredImage {
				name = ("transient-layers-" + buildInfo.name);
				tag = buildInfo.tag;
				contents = imagePackages ++ buildInfo.packages ++ [ nodeModules ];
			};
			in
				# https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/default.nix contains all available attributes.
				pkgs.unstable.dockerTools.buildImage {
					name = buildInfo.name;
					tag = buildInfo.tag;
					fromImage = transient-layers;
					# Nix is building the container in a workspace, links should always be ./ which will result in / in the final container
					extraCommands = ''
						# Examples
						# mkdir -p ./var/lib/mysql
						# ln -s "${pkgs.bash}/bin/bash"  ./bash
					'';
					config = ({
						Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
					} // buildInfo.config // { Env = buildInfo.config.Env ++ [ pathProd ]; });
				};
		# Note: '.env' is chaining up into nodeModules causing nodeModules to run after and erase the 'env' setting. At this time its not possible to place a node application with all 'Development' dependencies into a container.
		debug = let
			transient-layers = pkgs.unstable.dockerTools.buildLayeredImage {
				name = ("transient-layers-" + buildInfo.name + "-debug");
				tag = buildInfo.tag;
				contents = imagePackages ++ imagePackagesDebug ++ buildInfo.packages ++ [ nodeModules ];
			};
			in
				pkgs.unstable.dockerTools.buildImage {
					name = buildInfo.name + "-debug";
					tag = buildInfo.tag;
					fromImage = transient-layers;
					config = ({
						Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
					} // buildInfo.config // { Env = buildInfo.config.Env ++ [ pathDebug ]; });
				};
}
