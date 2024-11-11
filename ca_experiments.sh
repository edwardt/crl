#!/bin/bash
#set -e

#Directories:
CURDIR=${PWD}
ROOT_CA_DIRECTORY=${CRUDIR}/etc/ssl/testCA
INTERMEDIATE_CA1_DIRECTORY=${CRUDIR}/etc/ssl/intermediateTestCA1
INTERMEDIATE_CA2_DIRECTORY=${CRUDIR}/etc/ssl/intermediateTestCA2
INTERMEDIATE_CA3_DIRECTORY=${CRUDIR}/etc/ssl/intermediateTestCA3
CRL_SERVER_DIRECTORY=${CRUDIR}/var/www/localhost/pki
DEFAULT_CERTS_DIRECTORY=certs
DEFAULT_CRL_DIRECTORY=crl
DEFAULT_NEWCERTS_DIRECTORY=newcerts
DEFAULT_PRIVATE_DIRECTORY=private
DEFAULT_INDEX_FILE_NAME=index.txt
DEFAULT_ATTR_SUFFIX=.attr
DEFAULT_SERIAL_FILE_NAME=serial
DEFAULT_CRL_NUMBER_FILE_NAME=crlnumber

#File names:
DEFAULT_CONF_FILE_SUFFIX=.cnf
DEFAULT_CA_CONF_FILE_NAME="openssl.ca${DEFAULT_CONF_FILE_SUFFIX}"
DEFAULT_CHAIN_FILE_SUFFIX=_chain
DEFAULT_FULL_CHAIN_FILE_SUFFIX=_full_chain
DEFAULT_ROOT_CA_CERT_FILE_NAME=root.cert.pem
DEFAULT_ROOT_CA_KEY_FILE_NAME=root.key.pem

#Misc:
STANDARD_PASSWORD=test
OCSP_BASE_PORT=2560

#Config blocks:
read -r -d '' INTERMEDIATE_CA_BLOCK <<EOC

[ usr_cert ]
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection
crlDistributionPoints = URI:http://pki/\\\${ENV::filePrefix}.crl
authorityInfoAccess = @ocsp_info

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated End-Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
crlDistributionPoints = URI:http://pki/\\\${ENV::filePrefix}.crl
authorityInfoAccess = @ocsp_info

[ ocsp_info ]
caIssuers;URI.0 = http://pki/\\\${ENV::filePrefix}.crt
OCSP;URI.0 = http://pki:\${ocspPort}

EOC

finish() {
  echo "Finishing up..."
  #read
  killall openssl >/dev/null 2>&1 || true
}
  popd >/dev/null 2>&1

trap finish EXIT

createCAConf() {

  local targetFilename=$1
  local filePrefix=$2
  local defaultCrlDays=$3
  local policy=$4
  local ocspPort=$5
  local CABlock

  if [[ -z "${targetFilename}" ]]; then
    targetFilename=${DEFAULT_CA_CONF_FILE_NAME}
  fi
  if [[ -z "${defaulrCrlDays}" ]]; then
    defaultCrlDays=128
  fi
  if [[ -z "${policy}" ]]; then
    policy=policy_strict
  fi
  if [[ -z "${ocspPort}" ]]; then
    ocspPort=${OCSP_BASE_PORT}
  fi
  if [[ -z "${filePrefix}" ]]; then
    filePrefix=root
  else
    #Intermediate CA
    CABlock=`echo -e "$(eval "echo -e \"${INTERMEDIATE_CA_BLOCK}\"")"`
  fi

cat << EOF > ${targetFilename}
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = .
certs             = \$dir/${DEFAULT_CERTS_DIRECTORY}
crl_dir           = \$dir/${DEFAULT_CRL_DIRECTORY}
new_certs_dir     = \$dir/${DEFAULT_NEWCERTS_DIRECTORY}
database          = \$dir/${DEFAULT_INDEX_FILE_NAME}
serial            = \$dir/${DEFAULT_SERIAL_FILE_NAME}
RANDFILE          = \$dir/${DEFAULT_PRIVATE_DIRECTORY}/.rand

# The root key and root certificate.
private_key       = \$dir/${DEFAULT_PRIVATE_DIRECTORY}/${filePrefix}.key.pem
certificate       = \$dir/${DEFAULT_CERTS_DIRECTORY}/${filePrefix}.cert.pem

# For certificate revocation lists.
crlnumber         = \$dir/${DEFAULT_CRL_NUMBER_FILE_NAME}
crl               = \$dir/crl/ca.crl.pem
crl_extensions    = crl_ext
default_crl_days  = ${defaultCrlDays}

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 9125
preserve          = no
policy            = ${policy}
utf8              = Yes

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca

[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
countryName_default             = DE
stateOrProvinceName_default     = Germany
localityName_default            = Somewhere
0.organizationName_default      = ahuemmer
#organizationalUnitName_default =
#emailAddress_default           =

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
extendedKeyUsage = serverAuth
#crlDistributionPoints = URI:http://pki/root_ca.crl
#authorityInfoAccess = OCSP;URI:http://pki:${ocspPort}

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
crlDistributionPoints = URI:http://pki/\${ENV::filePrefix}.crl
#authorityInfoAccess = OCSP;URI:http://pki:${ocspPort}
#caIssuers = URI:http://pki/root.crt
authorityInfoAccess = @intermediate_ocsp_info

[ intermediate_ocsp_info ]
caIssuers;URI.0 = http://pki/root.crt
OCSP;URI.0 = http://pki:${OCSP_BASE_PORT}

${CABlock}

[ crl_ext ]
authorityKeyIdentifier=keyid:always

[ v3_OCSP ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
#keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOF
}

prepareCADirectory() {
  local baseDirectory=$(pwd)

  if [[ -z "${baseDirectory}" ]]; then
    echo "No base directory given for prepareCADirectory!"
    exit 1
  fi

  mkdir -p "${baseDirectory}"

  if [[ ! -d "${baseDirectory}" ]]; then
    echo "Could not create base directory for prepareCADirectory!"
    exit 1
  fi

  pushd "${baseDirectory}" >/dev/null 2>&1

  rm ./* -rf
  mkdir "${DEFAULT_CERTS_DIRECTORY}" "${DEFAULT_CRL_DIRECTORY}" "${DEFAULT_NEWCERTS_DIRECTORY}" "${DEFAULT_PRIVATE_DIRECTORY}"
  chmod 700 "${DEFAULT_PRIVATE_DIRECTORY}"
  touch ${DEFAULT_INDEX_FILE_NAME}
  touch ${DEFAULT_INDEX_FILE_NAME}${DEFAULT_ATTR_SUFFIX}
  echo 1000 > ${DEFAULT_SERIAL_FILE_NAME}
  echo 01 > ${DEFAULT_CRL_NUMBER_FILE_NAME}

  popd >/dev/null 2>&1
}

createIntermediateCA() {
  local intermediateCANumber=$1
  local intermediateCADirectory="$(pwd)/etc/ssl/intermediateTestCA${intermediateCANumber}"
  local intermediateCAConfigFile="openssl.intermediate_ca${intermediateCANumber}.cnf"
  local intermediateCAName="intermediate_ca${intermediateCANumber}"
  local intermediateCAKeyFileName="intermediate_ca${intermediateCANumber}.key.pem"
  local intermediateCACSRFileName="intermediate_ca${intermediateCANumber}.csr"
  local intermediateCACertFileName="intermediate_ca${intermediateCANumber}.cert.pem"
  local intermediateCAOSCPCertFileName="intermediate_ca${intermediateCANumber}_oscp.crt"
  local rootCAConfigFile=${ROOT_CA_DIRECTORY}/openssl.ca.cnf
  local crlFile="${DEFAULT_CRL_DIRECTORY}/intermediate_ca${intermediateCANumber}.crl"

  prepareCADirectory "${intermediateCADirectory}"

  pushd ${intermediateCADirectory} >/dev/null 2>&1

  export filePrefix=ca

  local ocspPort=$((${OCSP_BASE_PORT} + ${intermediateCANumber}))

  createCAConf ${intermediateCAConfigFile} ${intermediateCAName} 10 policy_loose ${ocspPort}

  echo "Intermediate CA number ${intermediateCANumber}: Configuration created."

  openssl genrsa -passout pass:${STANDARD_PASSWORD} -aes256 -out ./${DEFAULT_PRIVATE_DIRECTORY}/${intermediateCAKeyFileName} 2048 >/dev/null 2>&1
  chmod 400 ./${DEFAULT_PRIVATE_DIRECTORY}/${intermediateCAKeyFileName}

  echo -e "\n\n\n\n\nTEST-INTERMEDIATE-CA${intermediateCANumber}\n\n" | SAN= openssl req -utf8 -passin pass:${STANDARD_PASSWORD} -config ./${intermediateCAConfigFile} -new -sha256 -key ./${DEFAULT_PRIVATE_DIRECTORY}/${intermediateCAKeyFileName} -out ./${intermediateCACSRFileName} >/dev/null 2>&1

  popd >/dev/null 2>&1

  echo "Intermediate CA number ${intermediateCANumber}: CA-CSR created."

  pushd ${ROOT_CA_DIRECTORY} >/dev/null 2>&1

  #export filePrefix="${intermediateCAName}"
  echo -e "y\ny\n" | openssl ca -config ${DEFAULT_CA_CONF_FILE_NAME} -passin pass:${STANDARD_PASSWORD} -extensions v3_intermediate_ca -days 9125 -notext -md sha256 -in ${intermediateCADirectory}/${intermediateCACSRFileName} -out ${DEFAULT_CERTS_DIRECTORY}/${intermediateCACertFileName} > /dev/null 2>&1
  export filePrefix=ca

  chmod 444 ${DEFAULT_CERTS_DIRECTORY}/${intermediateCACertFileName}
  cp ${DEFAULT_CERTS_DIRECTORY}/${intermediateCACertFileName} ${intermediateCADirectory}/${DEFAULT_CERTS_DIRECTORY}/${intermediateCACertFileName}

  echo "Intermediate CA number ${intermediateCANumber}: Intermediate CA cert created."
  popd >/dev/null 2>&1

  pushd ${intermediateCADirectory} >/dev/null 2>&1
  echo -e "\n\n\n\n\nOCSP\n\n" | openssl req -new -utf8 -nodes -config ${intermediateCAConfigFile} -out ocsp.csr -keyout ${DEFAULT_PRIVATE_DIRECTORY}/ocsp.key.pem -extensions v3_OCSP >/dev/null 2>&1
  echo -e "y\ny\n" | openssl ca -keyfile ${DEFAULT_PRIVATE_DIRECTORY}/${intermediateCAKeyFileName} -passin pass:${STANDARD_PASSWORD} -cert ${ROOT_CA_DIRECTORY}/${DEFAULT_CERTS_DIRECTORY}/${intermediateCACertFileName} -in ocsp.csr -out ${DEFAULT_CERTS_DIRECTORY}/${intermediateCAOSCPCertFileName} -config ${intermediateCAConfigFile} -extensions v3_OCSP >/dev/null 2>&1
  chmod 0400 ${DEFAULT_PRIVATE_DIRECTORY}/ocsp.key.pem

  rm ./*.csr

  echo "Intermediate CA number ${intermediateCANumber}: OCSP signing certificate created."

  openssl ca -config ${intermediateCAConfigFile} -passin pass:${STANDARD_PASSWORD} -gencrl -out ${crlFile}.pem >/dev/null 2>&1
  openssl crl -in ${crlFile}.pem -outform DER -out ${crlFile}
  ln -sf $(realpath ./${crlFile}) ${CRL_SERVER_DIRECTORY}/$(basename ${crlFile})
  echo "Intermediate CA number ${intermediateCANumber}: \"Empty\" CRL file created."

  openssl ocsp -rmd sha256 -port ${ocspPort} -text -index ${DEFAULT_INDEX_FILE_NAME} -CA ${DEFAULT_CERTS_DIRECTORY}/${intermediateCACertFileName} -rkey ${DEFAULT_PRIVATE_DIRECTORY}/ocsp.key.pem -rsigner ${DEFAULT_CERTS_DIRECTORY}/${intermediateCAOSCPCertFileName} -nmin 10 >responder.dat 2>&1 &
  echo "Intermediate CA number ${intermediateCANumber}: Started OCSP responder."

  popd >/dev/null 2>&1

  echo

}

createCertificate() {
  local intermediateCANumber=$1
  local certName=$2
  local intermediateCADirectory="$(pwd)/etc/ssl/intermediateTestCA${intermediateCANumber}"
  local intermediateCAConfigFile="openssl.intermediate_ca${intermediateCANumber}.cnf"
  local intermediateCACertFile=${DEFAULT_CERTS_DIRECTORY}/intermediate_ca${intermediateCANumber}.cert.pem
  local keyFileName="${certName}.key.pem"
  local CSRFileName="${certName}.csr"
  local certFileName="${certName}.cert.pem"
  local intermediateCAKeyFileName="intermediate_ca${intermediateCANumber}.key.pem"
  local certChainFileName="${certName}.cert${DEFAULT_CHAIN_FILE_SUFFIX}.pem"
  local fullCertChainFileName="${certName}.cert${DEFAULT_FULL_CHAIN_FILE_SUFFIX}.pem"

  pushd ${intermediateCADirectory} >/dev/null 2>&1
  openssl genrsa -out ${DEFAULT_PRIVATE_DIRECTORY}/${keyFileName} 2048 >/dev/null 2>&1
  chmod 400 ${DEFAULT_PRIVATE_DIRECTORY}/${keyFileName}
  export filePrefix="intermediate_ca${intermediateCANumber}"
  echo -e "\n\n\n\n\n${certName}\n\n" | SAN= openssl req -utf8 -config ${intermediateCAConfigFile} -extensions v3_intermediate_ca -key ${DEFAULT_PRIVATE_DIRECTORY}/${keyFileName} -new -sha256 -out ${CSRFileName} >/dev/null 2>&1
  echo -e "y\ny\n" | SAN= openssl ca -config ${intermediateCAConfigFile} -extensions server_cert -passin pass:${STANDARD_PASSWORD} -days 9125 -notext -md sha256 -in ${CSRFileName} -out ${DEFAULT_CERTS_DIRECTORY}/${certFileName} -keyfile ${DEFAULT_PRIVATE_DIRECTORY}/${intermediateCAKeyFileName} >/dev/null 2>&1
  export filePrefix=ca
  rm ${CSRFileName}
  cat ${DEFAULT_CERTS_DIRECTORY}/${certFileName} ${intermediateCACertFile} > ${DEFAULT_CERTS_DIRECTORY}/${certChainFileName}
  cat ${DEFAULT_CERTS_DIRECTORY}/${certChainFileName} ${ROOT_CA_DIRECTORY}/${DEFAULT_CERTS_DIRECTORY}/${DEFAULT_ROOT_CA_CERT_FILE_NAME} > ${DEFAULT_CERTS_DIRECTORY}/${fullCertChainFileName}
  popd  >/dev/null 2>&1

  echo "Created certificate \"${certName}\" for intermediate CA nr. ${intermediateCANumber}."
}

revokeCertificate() {
  local intermediateCANumber=$1
  local certName=$2
  local certFileName="${certName}.cert.pem"
  if [[ ${intermediateCANumber} -ne 0 ]]; then
    local intermediateCADirectory="$(pwd)/etc/ssl/intermediateTestCA${intermediateCANumber}"
    local intermediateCAConfigFile="openssl.intermediate_ca${intermediateCANumber}.cnf"
    local crlFile="${DEFAULT_CRL_DIRECTORY}/intermediate_ca${intermediateCANumber}.crl"
  else
    local intermediateCADirectory="${ROOT_CA_DIRECTORY}"
    local intermediateCAConfigFile="${DEFAULT_CA_CONF_FILE_NAME}"
    local crlFile="${DEFAULT_CRL_DIRECTORY}/ca.crl"
  fi

  pushd ${intermediateCADirectory} >/dev/null 2>&1
  openssl ca -config ${intermediateCAConfigFile} -passin pass:${STANDARD_PASSWORD} -revoke ${DEFAULT_CERTS_DIRECTORY}/${certFileName} >/dev/null 2>&1

  if [[ ${intermediateCANumber} -ne 0 ]]; then
    echo -n "Revoked certificate \"${certName}\" for intermediate CA nr. ${intermediateCANumber}."
  else
    echo -n "Revoked intermediate CA certificate for ${certName}."
  fi

  openssl ca -config ${intermediateCAConfigFile} -passin pass:${STANDARD_PASSWORD} -gencrl -out ${crlFile}.pem >/dev/null 2>&1
  openssl crl -in ${crlFile}.pem -outform DER -out ${crlFile}
  echo "  --> Created CRL file at $(pwd)/${crlFile}."

  popd >/dev/null 2>&1
}

checkStatusUsingCRL() {
  local intermediateCANumber=$1
  local certName=$2
  local intermediateCADirectory="$(pwd)/etc/ssl/intermediateTestCA${intermediateCANumber}"

  local certFileName="${certName}.cert.pem"
  if [[ ${intermediateCANumber} -ne 0 ]]; then
    echo -n "CRL  status of certificate \"${certName}\" of intermediate ca ${intermediateCANumber}: "
    #local crlFile="${DEFAULT_CRL_DIRECTORY}/intermediate_ca${intermediateCANumber}.crl"
    #local certFileToCheck="${DEFAULT_CERTS_DIRECTORY}/${certName}.cert${DEFAULT_CHAIN_FILE_SUFFIX}.pem"
    local certFileToCheck="${DEFAULT_CERTS_DIRECTORY}/${certName}.cert.pem"
    local intermediateCADirectory="/etc/ssl/intermediateTestCA${intermediateCANumber}"
    local intermediateCert="${DEFAULT_CERTS_DIRECTORY}/intermediate_ca${intermediateCANumber}.cert.pem"
    pushd ${intermediateCADirectory} >/dev/null 2>&1
    #echo "In $(pwd): cat ${crlFile} ${CA_DIRECTORY}/crl/ca.crl > crlChain.pem"
    #cat ${crlFile} ${CA_DIRECTORY}/crl/ca.crl > crlChain.pem
  else
    echo -n "CRL  status of intermediate ca ${intermediateCANumber} certificate \"${certName}\": "
    local crlFile="${ROOT_CA_DIRECTORY}/${DEFAULT_CRL_DIRECTORY}/ca.crl"
    local certFileToCheck="${DEFAULT_CERTS_DIRECTORY}/${certName}.cert.pem"
    local intermediateCADirectory="${ROOT_CA_DIRECTORY}"
    pushd ${intermediateCADirectory} >/dev/null 2>&1
    #cat ${crlFile} > crlChain.pem 
  fi
 
  cat "${ROOT_CA_DIRECTORY}/${DEFAULT_CERTS_DIRECTORY}/${DEFAULT_ROOT_CA_CERT_FILE_NAME}" ${intermediateCert} > CAChain.pem

  local result=$(openssl verify -extended_crl -verbose -crl_check_all -crl_download -CAfile CAChain.pem ${certFileToCheck} 2>&1)
  #local result=$(openssl verify -extended_crl -verbose -crl_check_all -crl_download -CAfile ${CA_DIRECTORY}/${DEFAULT_CERTS_DIRECTORY}/${DEFAULT_ROOT_CA_CERT_FILE_NAME} ${certFileToCheck} 2>&1)
  local retVal=$?
  #echo -e "\nResult (${retVal}):\n${result}\n---\n"
  
  local regex="error 23 at [0-9]+ depth lookup: certificate revoked"

  if [[ "${result}" =~ ${regex} ]]; then
    retVal=23
  fi

  if [[ ${retVal} -eq 0 ]]; then
    echo -e "\e[32mOK\e[0m"
  elif [[ ${retVal} -eq 23 ]]; then
    echo -e "\e[31mREVOKED\e[0m"
  else
    echo -e "\e[31mUNKOWN ERROR, code ${retVal}\e[0m"
  fi
  
}

checkStatusUsingOCSP() {
  local intermediateCANumber=$1
  local certName=$2

  if [[ ${intermediateCANumber} -ne 0 ]]; then
    echo -n "OCSP status of certificate \"${certName}\" of intermediate ca ${intermediateCANumber}: "
    local CADirectory="$(pwd)/etc/ssl/intermediateTestCA${intermediateCANumber}"
    local cacert="intermediate_ca${intermediateCANumber}.cert.pem"
    local ocspCert="intermediate_ca${intermediateCANumber}_oscp.crt"
    local intermediateCert="${ROOT_CA_DIRECTORY}/${DEFAULT_CERTS_DIRECTORY}/intermediate_ca${intermediateCANumber}.cert.pem"
  else
    echo -n "OCSP status of intermediate ca ${intermediateCANumber} certificate \"${certName}\": "
    local CADirectory="${ROOT_CA_DIRECTORY}"
    local cacert=${DEFAULT_ROOT_CA_CERT_FILE_NAME}
    local ocspCert="ocsp.crt"
  fi

  cat "${ROOT_CA_DIRECTORY}/${DEFAULT_CERTS_DIRECTORY}/${DEFAULT_ROOT_CA_CERT_FILE_NAME}" ${intermediateCert} > CAChain.pem

  local certFileToCheck="${CADirectory}/${DEFAULT_CERTS_DIRECTORY}/${certName}.cert.pem"
  local ocspPort=$((${OCSP_BASE_PORT} + ${intermediateCANumber}))

  #Seems we have to issue it once before the "real" test, as otherwise we will get "unknown" as response... Strange!
  openssl ocsp -CA CAChain.pem -url http://pki:${ocspPort} -resp_text -issuer ${CADirectory}/${DEFAULT_CERTS_DIRECTORY}/${cacert} -cert ${certFileToCheck} >/dev/null 2>&1 || true
  openssl ocsp -CA CAChain.pem -url http://pki:${ocspPort} -resp_text -issuer ${CADirectory}/${DEFAULT_CERTS_DIRECTORY}/${cacert} -cert ${certFileToCheck} >/dev/null 2>&1 || true
  #echo "--"
  local result=$(openssl ocsp -CA CAChain.pem -url http://pki:${ocspPort} -resp_text -issuer ${CADirectory}/${DEFAULT_CERTS_DIRECTORY}/${cacert} -cert ${certFileToCheck} 2>&1)
  #
  local retVal=$?
  #echo $result

  rm CAChain.pem

  local regex1="${certFileToCheck}: revoked"
  local regex2="${certFileToCheck}: good"
  local regex3="${certFileToCheck}: unknown"

  if [[ "${result}" =~ ${regex1} ]]; then
    echo -e "\e[31mREVOKED\e[0m"
  elif [[ "${result}" =~ ${regex3} ]]; then
    echo -e "\e[31mUNKNOWN\e[0m"
  elif [[ "${result}" =~ ${regex2} ]]; then
    echo -e "\e[32mOK\e[0m"
  else
    echo -e "\e[31mUNKOWN ERROR, code ${retVal}\e[0m"
    echo ${result}
  fi

}

prepareCADirectory "${ROOT_CA_DIRECTORY}"

pushd ${ROOT_CA_DIRECTORY} >/dev/null 2>&1

createCAConf

export filePrefix=ca

openssl genrsa -passout pass:${STANDARD_PASSWORD} -aes256 -out ${DEFAULT_PRIVATE_DIRECTORY}/${DEFAULT_ROOT_CA_KEY_FILE_NAME} 4096 >/dev/null 2>&1
chmod 400 ${DEFAULT_PRIVATE_DIRECTORY}/ca.key.pem >/dev/null 2>&1

echo -e "\n\n\n\n\nTEST-CA\n\n" | openssl req -utf8 -config ${DEFAULT_CA_CONF_FILE_NAME} -passin pass:${STANDARD_PASSWORD} -key ${DEFAULT_PRIVATE_DIRECTORY}/${DEFAULT_ROOT_CA_KEY_FILE_NAME} -new -x509 -days 7300 -sha256 -extensions v3_ca -out ${DEFAULT_CERTS_DIRECTORY}/${DEFAULT_ROOT_CA_CERT_FILE_NAME} >/dev/null 2>&1
chmod 444 ${DEFAULT_CERTS_DIRECTORY}/${DEFAULT_ROOT_CA_CERT_FILE_NAME} >/dev/null 2>&1

echo "Root-CA created."

echo -e "\n\n\n\n\nOCSP\n\n" | openssl req -new -utf8 -nodes -config ${DEFAULT_CA_CONF_FILE_NAME} -out ocsp.csr -keyout ${DEFAULT_PRIVATE_DIRECTORY}/ocsp.key.pem -extensions v3_OCSP >/dev/null 2>&1
echo -e "y\ny\n" | openssl ca -keyfile ${DEFAULT_PRIVATE_DIRECTORY}/${DEFAULT_ROOT_CA_KEY_FILE_NAME} -passin pass:${STANDARD_PASSWORD} -cert ${DEFAULT_CERTS_DIRECTORY}/${DEFAULT_ROOT_CA_CERT_FILE_NAME} -in ocsp.csr -out ${DEFAULT_CERTS_DIRECTORY}/ocsp.crt -config ${DEFAULT_CA_CONF_FILE_NAME} -extensions v3_OCSP >/dev/null 2>&1
chmod 0400 ${DEFAULT_PRIVATE_DIRECTORY}/ocsp.key.pem

echo "Root-CA OCSP signing certificate created."

openssl ca -config ${DEFAULT_CA_CONF_FILE_NAME} -passin pass:${STANDARD_PASSWORD} -gencrl -out ${DEFAULT_CRL_DIRECTORY}/root_ca.crl >/dev/null 2>&1
ln -sf $(realpath ./crl/root_ca.crl) ${CRL_SERVER_DIRECTORY}/root_ca.crl
echo "Root-CA CRL file (\"empty\") created."

openssl ocsp -rmd sha256 -port ${OCSP_BASE_PORT} -text -index ${DEFAULT_INDEX_FILE_NAME} -CA ${DEFAULT_CERTS_DIRECTORY}/${DEFAULT_ROOT_CA_CERT_FILE_NAME} -rkey ${DEFAULT_PRIVATE_DIRECTORY}/ocsp.key.pem -rsigner ${DEFAULT_CERTS_DIRECTORY}/ocsp.crt -nmin 10 >responder_root_ca.dat 2>&1 &
echo "Root-CA: Started OCSP responder."

popd >/dev/null 2>&1

echo

createIntermediateCA 1
createIntermediateCA 2
createIntermediateCA 3

createCertificate 1 im1_c1_ok
createCertificate 1 im1_c2_rev
createCertificate 1 im1_c3_ok

echo

createCertificate 2 im2_c1_ok
createCertificate 2 im2_c2_ok
createCertificate 2 im2_c3_ok

echo

createCertificate 3 im3_c1_ok
createCertificate 3 im3_c2_ok
createCertificate 3 im3_c3_rev


echo 

revokeCertificate 1 im1_c2_rev
revokeCertificate 3 im3_c3_rev
revokeCertificate 0 intermediate_ca2
revokeCertificate 0 intermediate_ca3

/etc/init.d/nginx restart >/dev/null

echo

checkStatusUsingCRL 1 im1_c1_ok
checkStatusUsingOCSP 1 im1_c1_ok
checkStatusUsingCRL 1 im1_c2_rev
checkStatusUsingOCSP 1 im1_c2_rev
checkStatusUsingCRL 1 im1_c3_ok
checkStatusUsingOCSP 1 im1_c3_ok

echo

checkStatusUsingCRL 2 im2_c1_ok
checkStatusUsingOCSP 2 im2_c1_ok
checkStatusUsingCRL 2 im2_c2_ok
checkStatusUsingOCSP 2 im2_c2_ok
checkStatusUsingCRL 2 im2_c3_ok
checkStatusUsingOCSP 2 im2_c3_ok

echo

checkStatusUsingCRL 3 im3_c1_ok
checkStatusUsingOCSP 3 im3_c1_ok
checkStatusUsingCRL 3 im3_c2_ok
checkStatusUsingOCSP 3 im3_c2_ok
checkStatusUsingCRL 3 im3_c3_rev
checkStatusUsingOCSP 3 im3_c3_rev

echo

checkStatusUsingCRL 0 intermediate_ca1
checkStatusUsingOCSP 0 intermediate_ca1
checkStatusUsingCRL 0 intermediate_ca2
checkStatusUsingOCSP 0 intermediate_ca2
checkStatusUsingCRL 0 intermediate_ca3
checkStatusUsingOCSP 0 intermediate_ca3
