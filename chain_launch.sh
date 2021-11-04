#!/bin/env bash
#
# Initialize Cryptodoge service, depending on mode of system requested
#

cd /cryptodoge

. ./activate

# Only the /root/.chia folder is volume-mounted so store cryptodoge within
mkdir -p /root/.chia/cryptodoge
rm -f /root/.cryptodoge
ln -s /root/.chia/cryptodoge /root/.cryptodoge 

mkdir -p /root/.cryptodoge/mainnet/log
cryptodoge init >> /root/.cryptodoge/mainnet/log/init.log 2>&1 

echo 'Configuring Cryptodoge...'
while [ ! -f /root/.cryptodoge/mainnet/config/config.yaml ]; do
  echo "Waiting for creation of /root/.cryptodoge/mainnet/config/config.yaml..."
  sleep 1
done
sed -i 's/log_stdout: true/log_stdout: false/g' /root/.cryptodoge/mainnet/config/config.yaml
sed -i 's/log_level: WARNING/log_level: INFO/g' /root/.cryptodoge/mainnet/config/config.yaml

# Loop over provided list of key paths
for k in ${keys//:/ }; do
  if [ -f ${k} ]; then
    echo "Adding key at path: ${k}"
    cryptodoge keys add -f ${k} > /dev/null
  else
    echo "Skipping 'cryptodoge keys add' as no file found at: ${k}"
  fi
done

# Loop over provided list of completed plot directories
if [ -z "${cryptodoge_plots_dir}" ]; then
  for p in ${plots_dir//:/ }; do
    cryptodoge plots add -d ${p}
  done
else
  for p in ${cryptodoge_plots_dir//:/ }; do
    cryptodoge plots add -d ${p}
  done
fi

sed -i 's/localhost/127.0.0.1/g' ~/.cryptodoge/mainnet/config/config.yaml

chmod 755 -R /root/.cryptodoge/mainnet/config/ssl/ &> /dev/null
cryptodoge init --fix-ssl-permissions > /dev/null 

# Start services based on mode selected. Default is 'fullnode'
if [[ ${mode} == 'fullnode' ]]; then
  if [ ! -f ~/.cryptodoge/mainnet/config/ssl/wallet/public_wallet.key ]; then
    echo "No wallet key found, so not starting farming services.  Please add your mnemonic.txt to /root/.chia and restart."
  else
    cryptodoge start farmer
  fi
elif [[ ${mode} =~ ^farmer.* ]]; then
  if [ ! -f ~/.cryptodoge/mainnet/config/ssl/wallet/public_wallet.key ]; then
    echo "No wallet key found, so not starting farming services.  Please add your mnemonic.txt to /root/.chia and restart."
  else
    cryptodoge start farmer-only
  fi
elif [[ ${mode} =~ ^harvester.* ]]; then
  if [[ -z ${farmer_address} || -z ${farmer_port} ]]; then
    echo "A farmer peer address and port are required."
    exit
  else
    if [ ! -f /root/.cryptodoge/farmer_ca/cryptodoge_ca.crt ]; then
      mkdir -p /root/.cryptodoge/farmer_ca
      response=$(curl --write-out '%{http_code}' --silent http://${controller_host}:8932/certificates/?type=cryptodoge --output /tmp/certs.zip)
      if [ $response == '200' ]; then
        unzip /tmp/certs.zip -d /root/.cryptodoge/farmer_ca
      else
        echo "Certificates response of ${response} from http://${controller_host}:8932/certificates/?type=cryptodoge.  Try clicking 'New Worker' button on 'Workers' page first."
      fi
      rm -f /tmp/certs.zip 
    fi
    if [ -f /root/.cryptodoge/farmer_ca/cryptodoge_ca.crt ]; then
      cryptodoge init -c /root/.cryptodoge/farmer_ca 2>&1 > /root/.cryptodoge/mainnet/log/init.log
      chmod 755 -R /root/.cryptodoge/mainnet/config/ssl/ &> /dev/null
      cryptodoge init --fix-ssl-permissions > /dev/null 
    else
      echo "Did not find your farmer's certificates within /root/.cryptodoge/farmer_ca."
      echo "See: https://github.com/raingggg/coctohug/wiki"
    fi
    cryptodoge configure --set-farmer-peer ${farmer_address}:${farmer_port}
    cryptodoge configure --enable-upnp false
    cryptodoge start harvester -r
  fi
elif [[ ${mode} == 'plotter' ]]; then
    echo "Starting in Plotter-only mode.  Run Plotman from either CLI or WebUI."
fi
