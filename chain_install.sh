#!/bin/env bash
#
# Installs Cryptodoge as per https://github.com/CryptoDoge-Network/cryptodoge
#
CRYPTODOGE_BRANCH=$1

if [ -z ${CRYPTODOGE_BRANCH} ]; then
	echo 'Skipping Cryptodoge install as not requested.'
else
	rm -rf /root/.cache
	git clone --branch ${CRYPTODOGE_BRANCH} --single-branch https://github.com/CryptoDoge-Network/cryptodoge.git /cryptodoge \
		&& cd /cryptodoge \
		&& git submodule update --init mozilla-ca \
		&& chmod +x install.sh \
		&& /usr/bin/sh ./install.sh

	if [ ! -d /chia-blockchain/venv ]; then
		cd /
		rmdir /chia-blockchain
		ln -s /cryptodoge /chia-blockchain
		ln -s /cryptodoge/venv/bin/cryptodoge /chia-blockchain/venv/bin/chia
	fi
fi
