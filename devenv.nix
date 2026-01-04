{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "PVE T2 Kernel Repository Development Environment";

  # https://devenv.sh/packages/
  packages = with pkgs; [
    # Core tools for the repository
    aptly       # Debian repository management
    gnupg       # GPG signing
    jq          # JSON processing
    wget        # Package downloads
    curl        # API requests
    git         # Version control

    # Optional but useful
    tree        # Directory visualization
  ];

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo "$GREET"
    echo ""
    echo "Available tools:"
    echo "  - aptly: $(aptly version | head -1)"
    echo "  - gpg: $(gpg --version | head -1)"
    echo "  - jq: $(jq --version)"
    echo ""
    echo "GPG Key ID: $(cat .gpg-key-id 2>/dev/null || echo 'Not yet generated')"
    echo ""
    echo "Run './scripts/update-repo.sh' to build the repository"
  '';

  scripts.test-repo.exec = ''
    echo "Testing repository generation..."
    if [ ! -f .gpg-key-id ]; then
      echo "Error: GPG key not generated yet"
      exit 1
    fi
    ./scripts/update-repo.sh
  '';

  scripts.clean-repo.exec = ''
    echo "Cleaning aptly database and published repository..."
    rm -rf ~/.aptly
    rm -rf docs/*
    echo "Done!"
  '';

  enterShell = ''
    hello
  '';

  # https://devenv.sh/languages/
  # No specific language needed, but we could enable if we add scripts

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

  # https://devenv.sh/processes/
  # processes.ping.exec = "ping example.com";

  # See full reference at https://devenv.sh/reference/options/
}
