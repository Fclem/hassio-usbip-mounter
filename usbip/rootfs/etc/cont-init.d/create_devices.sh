#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: USBIP Mounter
# Configures USBIP devices
# ==============================================================================

# Configure mount script for all usbip devices
declare server_address
declare bus_id
declare script_directory
declare mount_script

script_directory="/usr/local/bin"
mount_script="/usr/local/bin/mount_devices"

if ! bashio::fs.directory_exists "${script_directory}"; then
  bashio::log.info  "Creating script directory"
  mkdir -p "${script_directory}" || bashio::exit.nok "Could not create bin folder"
fi

if bashio::fs.file_exists "${mount_script}"; then
  rm "${mount_script}"
fi

if ! bashio::fs.file_exists "${mount_script}"; then
  touch ${mount_script}
  chmod +x ${mount_script}
  echo '#!/command/with-contenv bashio' > "${mount_script}"
  echo 'set -x' >> "${mount_script}"
  echo 'mount -o remount -t sysfs sysfs /sys' >> "${mount_script}"
  for device in $(bashio::config 'devices|keys'); do
    server_address=$(bashio::config "devices[${device}].server_address")
    bus_id=$(bashio::config "devices[${device}].bus_id")
    bashio::log.info "Adding device from server ${server_address} on bus ${bus_id}"

    echo "out=\$(/usr/sbin/usbip --debug attach -r ${server_address} -b ${bus_id} 2>&1) || rc=\$?" >> "${mount_script}"
    echo "if echo \"\$out\" | grep -q \"Device busy (exported)\"; then" >> "${mount_script}"
    echo "  bashio::log.info \"Device ${bus_id} already attached (busy/exported). Skipping.\"" >> "${mount_script}"
    echo "  rc=0" >> "${mount_script}"
    echo "fi" >> "${mount_script}"
    echo "if [ \"\${rc:-0}\" -ne 0 ]; then" >> "${mount_script}"
    echo "  bashio::log.error \"Attach failed for ${server_address} ${bus_id}: \$out\"" >> "${mount_script}"
    echo "  exit \"\$rc\"" >> "${mount_script}"
    echo "fi" >> "${mount_script}"
  done
fi
