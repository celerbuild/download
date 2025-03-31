#!/bin/bash

VERSION="0.8.8"

# Detect OS and architecture
detect_os_arch() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"

    # Map architecture names
    case "$ARCH" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;; # aarch64 is the Linux name for arm64
        arm64)   ARCH="arm64" ;;
        *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    # Check supported operating systems
    case "$OS" in
        linux|darwin) : ;;
        *) echo "Unsupported operating system: $OS"; exit 1 ;;
    esac
}

# Check if celerbuild is already installed and compare versions
check_current_version() {
    if command -v celerbuild >/dev/null 2>&1; then
        CURRENT_VERSION=$(celerbuild --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        echo "Current version: $CURRENT_VERSION"
        echo "Latest version: $VERSION"

        if [ "$CURRENT_VERSION" = "$VERSION" ]; then
            echo "You already have the latest version installed."
            exit 0
        fi
    fi
}

# Download and install CelerBuild
install_celerbuild() {
    FILENAME="celerbuild-${VERSION}-${OS}-${ARCH}"
    DOWNLOAD_URL="https://raw.githubusercontent.com/celerbuild/download/refs/heads/main/${FILENAME}.tar.gz"

    echo "Downloading celerbuild ${VERSION} (${OS}-${ARCH})..."
    echo "Download URL: ${DOWNLOAD_URL}"

    # Create temporary directory for downloads
    TMP_DIR=$(mktemp -d)

    # Try downloading with curl first, then wget as fallback
    if command -v curl >/dev/null 2>&1; then
        # Add -f flag to fail on HTTP errors
        if ! curl -f -L -o "${TMP_DIR}/celerbuild.tar.gz" "${DOWNLOAD_URL}"; then
            echo "Error: Download failed with curl"
            echo "HTTP Status: $?"
            cat "${TMP_DIR}/celerbuild.tar.gz"
            rm -rf "${TMP_DIR}"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget --server-response -O "${TMP_DIR}/celerbuild.tar.gz" "${DOWNLOAD_URL}"; then
            echo "Error: Download failed with wget"
            cat "${TMP_DIR}/celerbuild.tar.gz"
            rm -rf "${TMP_DIR}"
            exit 1
        fi
    else
        echo "Error: curl or wget is required for download"
        rm -rf "${TMP_DIR}"
        exit 1
    fi

    # Check if downloaded file size is reasonable (>1MB)
    FILE_SIZE=$(stat -f%z "${TMP_DIR}/celerbuild.tar.gz" 2>/dev/null || stat -c%s "${TMP_DIR}/celerbuild.tar.gz")
    if [ "$FILE_SIZE" -lt 1000000 ]; then
        echo "Error: Downloaded file is too small (${FILE_SIZE} bytes)"
        echo "File content:"
        cat "${TMP_DIR}/celerbuild.tar.gz"
        rm -rf "${TMP_DIR}"
        exit 1
    fi

    # Verify if the downloaded file is actually a gzip archive
    if ! file "${TMP_DIR}/celerbuild.tar.gz" | grep -q "gzip compressed data"; then
        echo "Error: Downloaded file is not a valid gzip archive"
        echo "File type:"
        file "${TMP_DIR}/celerbuild.tar.gz"
        rm -rf "${TMP_DIR}"
        exit 1
    fi

    # Extract the archive
    if ! tar -xzf "${TMP_DIR}/celerbuild.tar.gz" -C "${TMP_DIR}"; then
        echo "Error: Failed to extract archive"
        rm -rf "${TMP_DIR}"
        exit 1
    fi

    # Notify user about sudo requirement
    echo "This installation requires sudo privileges to install to /usr/local/bin"

    # Create installation directory if it doesn't exist
    if ! sudo mkdir -p /usr/local/bin; then
        echo "Error: Failed to create /usr/local/bin directory"
        rm -rf "${TMP_DIR}"
        exit 1
    fi

    # Move binary to installation directory
    if ! sudo mv "${TMP_DIR}/${FILENAME}" /usr/local/bin/celerbuild; then
        echo "Error: Failed to move binary to /usr/local/bin"
        rm -rf "${TMP_DIR}"
        exit 1
    fi

    # Set executable permissions
    if ! sudo chmod +x /usr/local/bin/celerbuild; then
        echo "Error: Failed to set executable permissions"
        rm -rf "${TMP_DIR}"
        exit 1
    fi

    # Clean up temporary files
    rm -rf "${TMP_DIR}"

    # Verify successful installation
    if command -v celerbuild >/dev/null 2>&1; then
        if [ -n "$CURRENT_VERSION" ]; then
            echo "Successfully upgraded celerbuild from $CURRENT_VERSION to $VERSION!"
        else
            echo "Successfully installed celerbuild $VERSION!"
        fi
        return 0
    else
        echo "Error: Installation verification failed"
        exit 1
    fi
}

# Verify installation and display usage information
verify_installation() {
    echo -e "\nVerifying installation..."

    if ! command -v celerbuild >/dev/null 2>&1; then
        echo "Error: celerbuild installation failed"
        exit 1
    fi

    echo -e "\n=== Version Information ==="
    celerbuild --version

    echo -e "\n=== Quick Start ==="
    echo "1. celerbuild --help    # Show help information"
    echo "2. celerbuild          # Run celerbuild"
    echo "3. celerbuild --version # Check version"

    echo -e "\nFor more information, visit: https://celerbuild.com/docs/"
}

# Main program execution
main() {
    detect_os_arch
    check_current_version
    install_celerbuild
    verify_installation
}

main