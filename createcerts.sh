# preconditions
# * (On Windows) Cygwin
# * openssl version 1.1.* or newer installed
# * openssl.cnf is available in your working directory

# Run in Cygwin with "./CreateCerts.sh"
# One ca (root) and one sub-ca certificate will be created. Multiple client certificates will be signed with the same sub-ca certificate

# Certificates and keys will be created for each of these clients:
clients=( w2e e2w ago-energy rsc-energy )

# See the created certificates and private keys in folder "results"

baseDir=temp
resultDir=result

rm -r $baseDir $resultDir
mkdir -p $baseDir $resultDir
cd $baseDir

######################################
# 0. Global variables
# some dmmy test parameters
######################################
country=US
stateOrProvinceName=CA
organization=splunk
export crlUrl="http://crl.test.com/crl"
export email="test@test.com"
passw=b2bbp

######################################
# 1. Root-CA Key & Certificate
######################################

unit=ca
fullNameCA=$organization-$unit
export fullName=$fullNameCA
subject="/C=$country/ST=$stateOrProvinceName/O=$organization/OU=$unit/CN=$fullNameCA"

######################################
# 1.1 install root-ca directory & database
######################################

mkdir -p $fullNameCA
cd $fullNameCA
cp ../../openssl.cnf .
mkdir -p private certs newcerts
# database file indext.txt
touch index.txt

######################################
# 1.2 create private key
######################################

# create the keypair. Algorithm is RSA-PSS. The key size is 4096; the exponent is 65537.
openssl genpkey -algorithm RSA-PSS -pkeyopt rsa_keygen_bits:4096 -pkeyopt rsa_keygen_pubexp:65537 -pass pass:$passw -out private/$fullNameCA.key

######################################
# 1.3 create self-signed certificate
######################################

# create the certificate
openssl req -config openssl.cnf -key private/$fullNameCA.key -new -x509 -days 3650 -sha256 -extensions v3_ca -passin pass:$passw -subj $subject -out certs/$fullNameCA.cer

# verify
echo
echo $fullNameCA certificate:
openssl x509 -noout -text -in certs/$fullNameCA.cer

######################################
# 1.4 copy certificate to results
######################################
cp certs/$fullNameCA.cer ../../$resultDir

######################################
# 2. Sub-CA Key & Certificate
######################################

unit=sub-ca
fullNameSubCA=$organization-$unit
export fullName=$fullNameSubCA
subject="/C=$country/ST=$stateOrProvinceName/O=$organization/OU=$unit/CN=$fullNameSubCA"
export crlUrl=http://localhost:8080/sample/$fullNameSubCA.crl

######################################
# 2.1 install sub-ca directory & database
######################################

cd ..
mkdir -p $fullNameSubCA
cd $fullNameSubCA
cp ../../openssl.cnf .
mkdir -p private certs newcerts csr crl crl/ok crl/revoked
# database file indext.txt
touch index.txt

######################################
# 2.2 create private key
######################################

# create the keypair. Algorithm is RSA-PSS. The key size is 4096; the exponent is 65537.
openssl genpkey -algorithm RSA-PSS -pkeyopt rsa_keygen_bits:4096 -pkeyopt rsa_keygen_pubexp:65537 -pass pass:$passw -out private/$fullNameSubCA.key

######################################
# 2.3 request certificate signing
######################################

# create the request
openssl req -config openssl.cnf -key private/$fullNameSubCA.key -new -sha256 -passin pass:$passw -subj $subject -out csr/$fullNameSubCA.csr

# verify
echo
echo $fullNameSubCA certificate sign request:
openssl req -config openssl.cnf -noout -text -in csr/$fullNameSubCA.csr -verify

######################################
# 2.4 sign certificate
######################################

cd ../$fullNameCA
export fullName=$fullNameCA

# sign the certificate
# use policy_strict to sign intermediate certificates
# expires after 5 years
openssl ca -config openssl.cnf -days 1825 -notext -md sha256 -batch -extensions v3_intermediate_ca -policy policy_strict -rand_serial -in ../$fullNameSubCA/csr/$fullNameSubCA.csr -passin pass:$passw -out ../$fullNameSubCA/certs/$fullNameSubCA.cer

# verify
echo
echo $fullNameSubCA certificate:
openssl x509 -noout -text -in ../$fullNameSubCA/certs/$fullNameSubCA.cer

######################################
# 2.5 create empty CRL 
######################################
cd ../$fullNameSubCA
export fullName=$fullNameSubCA
openssl ca -config openssl.cnf -gencrl -passin pass:$passw -batch -out crl/ok/$fullNameSubCA.crl

# verify
echo
echo $fullNameSubCA crl:
openssl crl -in crl/ok/$fullNameSubCA.crl -noout -text

######################################
# 2.6 copy certificate and crl to results
######################################
cp certs/$fullNameSubCA.cer ../../$resultDir
mkdir -p ../../$resultDir/crl-ok
cp crl/ok/$fullNameSubCA.crl ../../$resultDir/crl-ok


######################################
# 3. Market partner keys, certificates & related CRLs
######################################

for fullNameClient in "${clients[@]}"
do

    export fullName=$fullNameClient
    # best practise: unique name for every certificate -> solved here with current date
    date=$(date +%Y%m%d-%H%M%S)
    cn=$fullNameClient-$date
    subject="/C=$country/ST=$stateOrProvinceName/O=$fullNameClient/CN=$cn"
    export email=$fullNameClient@b2bbp.org


    ######################################
    # 3.1 install market partner directory
    ######################################

    cd ..
    mkdir -p $fullNameClient
    cd $fullNameClient
    cp ../../openssl.cnf .
    mkdir -p private certs csr

    ######################################
    # 3.2 create private key
    ######################################

    # create the keypair. The key size is 4096; the exponent is 65537
    # New versions of openssl use a longer salt. With key size 3072 Bouncy Castle produces an error "key too small for specified hash and salt lengths". 
    # Therefore the key size cannot be less than 4096
    openssl genpkey -algorithm RSA-PSS -pkeyopt rsa_keygen_bits:4096 -pkeyopt rsa_keygen_pubexp:65537 -pass pass:$passw -out private/$fullNameClient.key

    ######################################
    # 3.3 request certificate signing
    ######################################

    # create the request
    openssl req -config openssl.cnf -key private/$fullNameClient.key -new -sha256 -passin pass:$passw -subj $subject -out csr/$fullNameClient.csr

    # verify
    echo
    echo $fullNameClient certificate sign request:
    openssl req -config openssl.cnf -noout -text -in csr/$fullNameClient.csr -verify

    ######################################
    # 3.4 sign certificate
    ######################################

    cd ../$fullNameSubCA
    export fullName=$fullNameSubCA

    # sign the certificate
    # use policy_loose to sign client certificates
    # expires after 3 years
    openssl ca -config openssl.cnf -days 1095 -notext -md sha256 -batch -extensions usr_cert -policy policy_loose -rand_serial -in ../$fullNameClient/csr/$fullNameClient.csr -passin pass:$passw -out ../$fullNameClient/certs/$fullNameClient.cer

    # verify
    echo
    echo $fullNameClient certificate:
    openssl x509 -noout -text -in ../$fullNameClient/certs/$fullNameClient.cer

    ######################################
    # 3.5 p12 key format
    ######################################

    cd ../$fullNameClient
    openssl pkcs12 -export -in certs/$fullNameClient.cer -inkey private/$fullNameClient.key -passin pass:$passw -passout pass:$passw > private/$fullNameClient.p12

    #verify
    echo
    echo $fullNameClient p12 certificate:
    openssl pkcs12 -noout -info -in private/$fullNameClient.p12 -passin pass:$passw

    ######################################
    # 3.7 revoke client certificate
    ######################################

    cd ../$fullNameSubCA
    openssl ca -config openssl.cnf -passin pass:$passw -batch -revoke ../$fullNameClient/certs/$fullNameClient.cer
    
    ######################################
    # 3.8 copy certificate and keys to results
    ######################################
    cd ../$fullNameClient
    cp private/$fullNameClient.p12 ../../$resultDir
    cp certs/$fullNameClient.cer ../../$resultDir

done

######################################
# 4 create CRL with revoked certificates
######################################

# create
cd ../$fullNameSubCA
openssl ca -config openssl.cnf -gencrl -passin pass:$passw -batch -out crl/revoked/$fullNameSubCA.crl

# verify
echo
echo $fullNameSubCA revoked crl:
openssl crl -in crl/revoked/$fullNameSubCA.crl -noout -text

# copy
mkdir -p ../../$resultDir/crl-revoked
cp crl/revoked/$fullNameSubCA.crl ../../$resultDir/crl-revoked