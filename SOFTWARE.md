# Additional software

## Hardware platform

### NVMe
```bash
aurman -Syu nvme-cli
```

### Tuxedo
```bash
aurman -Syu tuxedo-drivers-dkms
aurman -Syu tuxedo-control-center-bin
aurman -Syu tuxedo-touchpad-switch
sudo systemctl enable tccd.service
sudo systemctl enable tccd-sleep.service
```

### MTP
Install MTP and add the current user to the group `uucp`:
```bash
aurman -Syu libmtp
sudo gpasswd -a $USER uucp
```

### ADB
Install android platform tools and add the current user to the group `adbusers`:
```bash
aurman -Syu android-tools
sudo gpasswd -a $USER adbusers
```

## Security related

### Command for shredding files
Add a function to the `.bashrc`:
```bash
function shred {
  /usr/bin/shred "$1" && rm "$1"
}
```

### YubiKey
Management:
```bash
aurman -Syu yubikey-manager yubikey-manager-qt
```
Make sure `pcscd.service` is enabled.
Status info for a YubiKey version 5 via `ykman info`.

Authenticator App:
```bash
aurman -Syu yubico-authenticator-bin
```

### FIDO2 / U2F and WebAuthn
```bash
aurman -Syu libfido2
```
WebAuthn test site: https://demo.yubico.com/webauthn-technical/registration


## Desktop Environment

### Additional Gnome settings
```bash
# favorite apps
gsettings set org.gnome.shell favorite-apps "['org.gnome.Terminal.desktop', 'org.gnome.Nautilus.desktop', 'firefox.desktop', 'org.keepassxc.KeePassXC.desktop']"
# gnome-terminal settings
gsettings set org.gnome.Terminal.Legacy.Settings theme-variant 'dark'
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" audible-bell false
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" background-color 'rgb(46,52,54)'
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" bold-is-bright true
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" cursor-shape 'ibeam'
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" default-size-columns 120
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" default-size-rows 30
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" font 'Jetbrains Mono NL 11.5'
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" foreground-color 'rgb(211,215,207)'
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" palette "['rgb(46,52,54)', 'rgb(204,0,0)', 'rgb(78,154,6)', 'rgb(196,160,0)', 'rgb(52,101,164)', 'rgb(117,80,123)', 'rgb(6,152,154)', 'rgb(211,215,207)', 'rgb(85,87,83)', 'rgb(239,41,41)', 'rgb(138,226,52)', 'rgb(252,233,79)', 'rgb(114,159,207)', 'rgb(173,127,168)', 'rgb(52,226,226)', 'rgb(238,238,236)']"
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" scrollback-lines 1000000
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" use-system-font false
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$(profile=$(gsettings get org.gnome.Terminal.ProfilesList default); echo ${profile:1:-1})/" use-theme-colors false
# reset gnome app-picker layout (overview)
gsettings set org.gnome.shell app-picker-layout "[]"
# add minimize and maximize buttons on windows
gsettings set org.gnome.desktop.wm.preferences button-layout "'appmenu:minimize,maximize,close'"
# disable software updates via Gnome Software
gsettings set org.gnome.software allow-updates false
gsettings set org.gnome.software download-updates false
```

### Gnome extensions
```bash
aurman -Syu gnome-browser-connector
```
Firefox browser extension:
https://addons.mozilla.org/de/firefox/addon/gnome-shell-integration

Used extensions:
- Dash to Dock
- Just Perfection
- No overview at start-up
- Removable Drive Menu
- Tiling Assistant
- Tray Icons: Reloaded
- User Themes

## Office

### Thunderbird
```bash
aurman -Syu thunderbird thunderbird-i18n-de
# spell checking
aurman -Syu hunspell hunspell-en_US hunspell-de
```
Extensions for Exchange compatibility:
- [Provider für Exchange ActiveSync](https://addons.thunderbird.net/de/thunderbird/addon/eas-4-tbsync/)
- [TbSync](https://addons.thunderbird.net/de/thunderbird/addon/tbsync/)

### LibreOffice
```bash
aurman -Syu libreoffice-fresh libreoffice-fresh-de
```

## Multimedia

### VLC
Install vlc media player via
```bash
aurman -Syu vlc vlc-plugins-all
```
After installation start vlc and go to the preferences -> Interface section -> Embed video in interface:
- uncheck, save
- check, save

Possible preferences bug: see https://superuser.com/a/126528, #48

Additionally check the following if vlc crashes on playback:
Go to preferences -> Show settings: all -> Video - Output module -> Video output module: VDPAU-Output,
then save

### Tenacity
```bash
aurman -Syu tenacity
```

### MediathekView
Add a pacman hook for installing and updating the `mediathekview` file in case of Hi-DPI Monitors:
```bash
sudo nano /etc/pacman.d/hooks/mediathekviewupgrade.hook
```
Content:
```text
[Trigger]
Operation=Install
Operation=Upgrade
Type=Package
Target=mediathekview
[Action]
Description=Updating mediathekview file after upgrade...
When=PostTransaction
Depends=sed
Exec=/bin/sh -c "sed -i 's/\(.*-jar .*\)/  -Dsun.java2d.uiScale=2\n\1/' /usr/bin/mediathekview"
```

```bash
aurman -Syu mediathekview-xdg
```

## Development and Editors

### VSCodium
```bash
aurman -Syu vscodium-bin vscodium-bin-marketplace
# reinstall to be sure that the 'product.json' is patched by the hooks
aurman -Syu vscodium-bin
```

#### Alias
```bash
nano ~/.bashrc
```
```text
alias code='vscodium'
```

#### Extensions
- [GitHub Markdown Preview (Matt Bierner)](https://marketplace.visualstudio.com/items?itemName=bierner.github-markdown-preview)
- [Python (Microsoft)](https://marketplace.visualstudio.com/items?itemName=ms-python.python)

### Java
```bash
aurman -Syu jdk-openjdk openjdk-doc openjdk-src
# optional: latest LTS release
aurman -Syu jdk21-openjdk openjdk21-doc openjdk21-src

# status
archlinux-java status

# optional: set active default Java version
sudo archlinux-java set java-21-openjdk
```

### Eclipse IDE
Add a pacman hook for updating the `eclipse.desktop` file:
```bash
sudo nano /etc/pacman.d/hooks/eclipseupgrade.hook
```
Content:
```text
[Trigger]
Operation=Install
Operation=Upgrade
Type=Package
Target=eclipse-java-bin
[Action]
Description=Updating eclipse.desktop file after upgrade...
When=PostTransaction
Depends=sed
Exec=/bin/sh -c "sed -i 's/\(Exec=\)\(.*\)/\1env GTK_THEME=Adwaita:dark \2/' /usr/share/applications/eclipse.desktop"
```
Install the IDE:
```bash
aurman -Syu eclipse-java-bin
```
Add an alias to the `.bashrc`:
```bash
alias eclipse='GTK_THEME=Adwaita:dark eclipse'
```

To resolve shortcut conflicts under Gnome configure the following:
```bash
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-down "['']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-up "['']"
```

**Workaround** for crashes due to [issue #7438](https://gitlab.gnome.org/GNOME/gtk/-/issues/7438):
```bash
aurman -Syu ibus
```

### JavaFX SceneBuilder
```bash
aurman -Syu javafx-scenebuilder
```

