
set -e

echo "\nStarting setup\n"

# echo "\n📦 Installing APT packages one by one...\n"
# while read pkg; do
#   if [ -n "$pkg" ] && [ "${pkg#\#}" = "$pkg" ]; then
#     echo "➡️ Installing $pkg..."
#     sudo apt install -y "$pkg" || echo "❌ Failed to install: $pkg"
#   fi
# done < manual-packages.txt

echo "🔧 Restoring shell configs..."
cp .bashrc ~/
cp .zshrc ~/ 2>/dev/null || echo "No .zshrc found."

if [ -f "flatpak-packages.txt" ]; then
  echo "\n📦 Installing Flatpak apps...\n"
  if ! command -v flatpakestoring shell configs... &>/dev/null; then
    sudo apt install flatpak -y
  fi
  while read pkg; do
    flatpak install -y --noninteractive flathub "$pkg" || echo "❗ Failed: $pkg"
  done < flatpak-packages.txt
fi

if [ -f "snap-packages.txt" ]; then
  echo "\n📦 Installing Snap apps...\n"
  if ! command -v snap &>/dev/null; then
    sudo apt install snapd -y
  fi
  while read pkg; do
    sudo snap install $pkg || echo "❗ Failed: $pkg"
  done < snap-packages.txt
fi

echo "\n🔌 Installing GNOME extensions...\n"

if ! command -v gnome-shell-extension-installer &> /dev/null; then
  echo "⬇️ Downloading gnome-shell-extension-installer..."
  sudo curl -o /usr/local/bin/gnome-shell-extension-installer \
    https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer
  sudo chmod +x /usr/local/bin/gnome-shell-extension-installer
fi

GNOME_VERSION=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1-2)
EXTENSION_LIST="enabled-extensions.txt"

echo "🧩 GNOME Version: $GNOME_VERSION"
echo "📄 Reading UUIDs from: $EXTENSION_LIST"
echo

while read -r UUID; do
  [ -z "$UUID" || "$UUID" == \#* ] && continue

  echo "🔍 Processing UUID: $UUID"

  RESPONSE=$(curl -sL "https://extensions.gnome.org/extension-info/?uuid=${UUID}&shell_version=${GNOME_VERSION}")

  # Validate JSON
  if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    echo "⚠️ Invalid or no response for $UUID"
    continue
  fi

  EXT_ID=$(echo "$RESPONSE" | jq -r '.pk // empty')

  if [ -z "$EXT_ID" || "$EXT_ID" == "null" ]; then
    echo "⚠️ No extension ID found for $UUID. May be preinstalled or unsupported."
    echo "➡️ Enabling manually if possible..."
    gnome-extensions enable "$UUID" 2>/dev/null || echo "❌ Could not enable $UUID"
    continue
  fi

  echo "📥 Installing extension: $UUID (ID: $EXT_ID)"
  if gnome-shell-extension-installer "$EXT_ID" --yes; then
    echo "✅ Installed $UUID"
    gnome-extensions enable "$UUID" || echo "⚠️ Failed to enable $UUID"
  else
    echo "❌ Failed to install $UUID (ID: $EXT_ID)"
  fi

  echo
done < "$EXTENSION_LIST"


if [ -f "gnome-settings.ini" ]; then
  echo "🎨 Restoring GNOME settings..."
  dconf load / < gnome-settings.ini
fi

if [ -f "enabled-extensions.txt" ]; then
  echo "\n🧩 Re-enabling GNOME extensions...\n"
  while read ext; do
    gnome-extensions enable "$ext" || echo "❗ Failed to enable: $ext"
  done < enabled-extensions.txt
fi

if [ -d "./themes" ]; then
  echo "\n🎨 Installing GTK themes...\n"
  mkdir -p ~/.themes
  cp -r themes/* ~/.themes/
fi

if [ -d "./icons" ]; then
  echo "\n🎨 Installing icon themes...\n"
  mkdir -p ~/.icons
  cp -r icons/* ~/.icons/
fi


GTK_THEME="Everforest-Dark"
ICON_THEME="Uos-fulldistro-icons-Dark"
SHELL_THEME="Everforest-Dark"
CURSOR_THEME="Afterglow-cursors"

gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com || true


gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"
gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"
gsettings set org.gnome.shell.extensions.user-theme name "$SHELL_THEME"


echo "✅ Setup complete! Please restart GNOME or reboot if needed."
