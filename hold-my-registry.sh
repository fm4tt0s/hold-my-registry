#!/usr/bin/env bash
#
# author    : Felipe Mattos
# email     : fmattos@gmx.com
# date      : 03/03/2020
# version   : 1.0
#
# purpose   : generates client and server self-signed certificates used
#       to enable HTTPS remote authentication to a Docker registry/daemon.
#       refs:
#           http://docs.docker.com/articles/https/
#           https://docs.docker.com/registry/deploying/
#
# remarks   : this will generate a set of files that matters to registry and
#       node machines. Registry box will use server certs, whereas node needs
#       only the client certificate - usually placed on
#       /etc/docker/certs.d/[registry_url]/ca.crt
#
# reqs      :
#       openssl
#

[[ -z "${BASH}" ]] && echo "ERROR: Run me from BASH!" >&2 && exit 1
[[ ! -x $(command -v openssl) ]] && echo "ERROR: OpenSSL is not installed!" >&2 && exit 1

# global vars
_scriptpath=$( cd "$(dirname "${BASH_SOURCE[0]}")" || return 0 ; pwd -P )
_spoolpath="${_scriptpath}/output.$$"

# bail it all in case anything fails
set -Eeuo pipefail

# in such case, get rid of output folder
trap _cleanup EXIT INT
_cleanup()
{
    [[ $? -ge 1 ]] && rm -rf "${_spoolpath}" && exit 1
}

# create runtime folder to place this run generated files
mkdir -p "${_spoolpath}"

# define cert validity - you can go crazy till 20y here, but remember the Y2038 problem
read -r -p "Certificate should be valid for N days (default, 730): " _days ; _days=${_days:-730}
if ! [[ "${_days}" =~ ^[0-9]+$ ]]; then
   echo "ERROR: ${_days} is not a valid number" >&2; exit 137
fi

# create a runtime password
_password=$(openssl rand -hex 16)
echo "${_password}" > "${_spoolpath}/password.file"

# get CNAMEs / IP / subjectAltName if any
read -r -p "CA Common Name: (ex, ACME - default, *) " _CACNane ; _CACNane=${_CACNane:-* } 
read -r -p "Registry Server Common Name: (ex, host123.acme.corp.com - default, *) " _ServerCNane ; _ServerCNane=${_ServerCNane:-*} 
_serverName="${_ServerCNane}"

read -r -p "Registry Server IP: (ex, 1.2.3.4 - default, 0.0.0.0) " _srvIP ; _srvIP=${_srvIP:-0.0.0.0} ; 
if ! [[ "${_srvIP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: ${_days} is not a valid IP" >&2; exit 137
fi

echo
# create a base extfile.cnf
echo "[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
subjectAltName = @alt_names
[alt_names]" > "${_spoolpath}"/extfile.cnf

echo "DNS.1 = ${_serverName}" >> "${_spoolpath}"/extfile.cnf
echo "IP.1 = ${_srvIP}" >> "${_spoolpath}"/extfile.cnf

# in case _serverName is not *, ask if want to use AltNames 
if ! [[ "${_serverName}" == "*" ]]; then
echo "--------------------------------------------------
You can use subjectAltName for the registry server. 
That's useful when the server has floating DNS or 
multiple names, for example.
--------------------------------------------------"

read -r -p "Do you want to use subjectAltNames for ${_serverName}? [y/n] - default, no) " _response ; _response=${_response:-n} 
if [[ "${_response}" == "yes" ]]; then
        if [[ -x $(command -v vi) ]]; then
            vi "${_spoolpath}"/extfile.cnf
        else
            echo "ERROR: Im unable to find VI"
            echo "Please edit ${_spoolpath}/extfile.cnf to add subjectAltName(s) (DNS.n/IP.n)"
            #DNS.1 = cool-external-name.acme.com
            #DNS.2 = scrambled-12345-name.corp.acme.com
            #DNS.3 = scrambled-56789-name.corp.acme.com
            #IP.1 = 1.2.4.5
            #IP.2 = 6.7.8.9
            #IP.3 = 10.11.12.13
        fi
        read -r -p "Hit [ENTER] to continue..."
fi
fi

# generate CA private and public keys
echo "01" > "${_spoolpath}"/ca.srl
openssl genrsa -des3 -out "${_spoolpath}"/ca-key.pem -passout pass:"${_password}" 2048
openssl req -subj "/CN=${_CACNane}/" -new -x509 -days "${_days}" -passin pass:"${_password}" -key "${_spoolpath}"/ca-key.pem -out "${_spoolpath}"/ca.pem

# create a server key and certificate signing request (CSR)
openssl genrsa -des3 -out "${_spoolpath}"/server-key.pem -passout pass:"${_password}" 2048
openssl req -new -key "${_spoolpath}"/server-key.pem -out "${_spoolpath}"/server.csr -passin pass:"${_password}" -subj "/CN=${_ServerCNane}/"

# sign the server key with our CA
openssl x509 -req -days "${_days}" -passin pass:"${_password}" -in "${_spoolpath}"/server.csr -CAserial "${_spoolpath}"/ca.srl -CA "${_spoolpath}"/ca.pem -CAkey "${_spoolpath}"/ca-key.pem -out "${_spoolpath}"/server-cert.pem

# create a client key and certificate signing request (CSR)
openssl genrsa -des3 -out "${_spoolpath}"/key.pem -passout pass:"${_password}" 2048
openssl req -subj "/CN=${_ServerCNane}/" -new -key "${_spoolpath}"/key.pem -out "${_spoolpath}"/client.csr -passin pass:"${_password}"

# get back to the extensions config file and sign
openssl x509 -req -days "${_days}" -passin pass:"${_password}" -in "${_spoolpath}"/client.csr -CAserial "${_spoolpath}"/ca.srl -CA "${_spoolpath}"/ca.pem -CAkey "${_spoolpath}"/ca-key.pem -out "${_spoolpath}"/cert.pem -extfile "${_spoolpath}"/extfile.cnf

# remove the passphrase from the client and server key
openssl rsa -in "${_spoolpath}"/server-key.pem -out "${_spoolpath}"/server-key.pem -passin pass:"${_password}"
openssl rsa -in "${_spoolpath}"/key.pem -out "${_spoolpath}"/key.pem -passin pass:"${_password}"

# rename / copy generated files to more meaninful names
mv "${_spoolpath}"/ca.pem "${_spoolpath}"/CLIENTCA.crt
mv "${_spoolpath}"/key.pem "${_spoolpath}"/KEY.pem
mv "${_spoolpath}"/cert.pem "${_spoolpath}"/CERTIFICATE.pem

echo ; echo "Done! Your files are under ${_spoolpath}" >&2;
exit 0
