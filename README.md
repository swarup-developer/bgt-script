# Wine Supervisor Setup

This project provides a streamlined script designed to automate the installation and configuration of Wine and Supervisor on a Linux system. It simplifies the process of setting up a Windows application to run as a service managed by Supervisor, ensuring it starts automatically on boot and handles runtime errors gracefully.

## Description

The `wine-supervisor-setup.sh` script addresses the common challenge of running Windows applications (often games or specific tools) on Linux environments. It automates the intricate steps involved in setting up Wine, including dependency installation and prefix configuration, and then integrates the application with the Supervisor process control system. This allows your Windows application to be managed like any other Linux service, providing reliability and ease of use.

The script intelligently checks if Wine is already installed, skipping unnecessary steps if it is. It guides the user through the configuration of a new Wine prefix, installs essential libraries and runtimes like `vcrun2013`, `vcrun6`, and `dotnet35sp1`, and then facilitates the creation of a Supervisor configuration file for the target Windows application. This includes options for autostarting the application on boot and saving output logs for debugging.

A user-friendly menu is provided for managing the Supervisor-managed application, allowing users to start, stop, restart, check status, back up configurations, remove existing applications, and set up new ones.

## Installation

This script is designed to be run directly on a Debian/Ubuntu-based Linux distribution.

**Prerequisites:**

*   A Linux distribution (e.g., Ubuntu, Debian).
*   `curl` utility installed.
*   `sudo` privileges.

**Steps:**

1.  **Download the script:**
    ```bash
    curl -o wine-supervisor-setup.sh https://raw.githubusercontent.com/swarup-developer/bgt-script/main/wine-supervisor-setup.sh
    ```
2.  **Make the script executable:**
    ```bash
    chmod +x wine-supervisor-setup.sh
    ```
3.  **Run the script:**
    ```bash
    ./wine-supervisor-setup.sh
    ```

The script will first check for updates and then proceed with the Wine and Supervisor installation and configuration.

## Usage

After running the installation script, you will be presented with the Supervisor Control Panel.

**Key Actions:**

*   **Setup New App (Option 6):** This is the primary function for adding a new Windows application. You will be prompted for:
    *   An application name (for Supervisor).
    *   The `.exe` filename of your application.
    *   The full path to the directory containing the `.exe`.
    *   Your Linux username (to run the application as).
    *   Whether to autostart the app on boot.
    *   Whether to save output logs.
*   **Start App (Option 1):** Starts a Supervisor-managed application.
*   **Stop App (Option 2):** Stops a Supervisor-managed application.
*   **Restart App (Option 3):** Restarts a Supervisor-managed application.
*   **Status (Option 4):** Displays the current status of all Supervisor-managed applications.
*   **Backup App Config (Option 5):** Creates a backup of a Supervisor configuration file.
*   **Remove Previously Installed App (Option 0):** Stops and removes an existing Supervisor configuration.

**Example Workflow for Setting Up an App:**

1.  Run the script: `./wine-supervisor-setup.sh`
2.  Choose option `6` (Setup New App).
3.  Enter an app name, e.g., `mygame`.
4.  Enter the `.exe` filename, e.g., `mygame.exe`.
5.  Enter the path to the folder, e.g., `/home/youruser/Games/MyGameFolder`.
6.  Enter your Linux username, e.g., `youruser`.
7.  Choose `yes` or `no` for autostart.
8.  Choose `yes` or `no` for log saving.
9.  The script will configure and start your application.
10. You can then use options `1` through `4` to manage `mygame`.

## Key Features

*   **Automated Wine Installation:** Installs Wine and essential dependencies, including a 32-bit environment for broader compatibility.
*   **Efficient Update Checking:** Automatically checks for newer versions of the setup script and prompts for an update.
*   **Smart Wine Setup:** Skips Wine installation if it's already present and sets up a clean Wine prefix.
*   **Essential Libraries Installation:** Installs crucial components like `corefonts`, `vcrun2013`, `vcrun6`, and `dotnet35sp1` for better application compatibility.
*   **Supervisor Integration:** Seamlessly configures Supervisor to manage your Windows application as a service.
*   **Flexible Application Configuration:** Allows customization of app name, executable path, user, autostart, and logging.
*   **User-Friendly Control Panel:** Provides an interactive menu for managing Supervisor services (start, stop, restart, status, backup, removal).
*   **Robust Error Handling:** Includes checks for file existence and provides feedback on application startup status.

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for more details.

## Contributing

We're thrilled you're interested in contributing to the Wine Supervisor Setup project! This project is all about making it easier for people to run their favorite Windows applications on Linux, and your help can make it even better. Whether you're looking to fix a bug, suggest a new feature, or improve the documentation, all contributions are welcome and appreciated. We aim for a friendly and collaborative environment where everyone feels comfortable sharing their ideas and code.

We encourage you to dive in, explore the code, and if you find something that could be improved, don't hesitate to open an issue or submit a pull request. Let's work together to enhance this tool for the community!

## Notes for Developers

*   **Script Structure:** The script is designed to be self-contained and executed directly. Key functionalities are encapsulated in functions for better organization.
*   **Error Handling:** While the script includes basic error checks, developers are encouraged to add more comprehensive validation and user feedback mechanisms.
*   **Dependency Management:** The script relies on `apt` for package management, making it suitable for Debian/Ubuntu-based systems. Adaptations might be needed for other Linux distributions.
*   **Update Mechanism:** The update check uses `curl` to fetch the script content and parse version information. Ensure the `SCRIPT_URL` is maintained and accessible.
*   **Wine Prefix Management:** The script uses `~/.wine32` with `win32` architecture for the Wine prefix. Modifications to this can impact application compatibility.
*   **Supervisor Configuration:** The script dynamically generates `.conf` files in `/etc/supervisor/conf.d/`. Understand Supervisor's configuration structure if making advanced changes.
*   **Testing:** Thorough testing on various Linux environments and with different Windows applications is crucial for ensuring broad compatibility and stability.