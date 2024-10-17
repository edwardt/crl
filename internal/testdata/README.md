Test Data Generation

https://medium.com/@arpanagupta10/understanding-certificate-revocation-list-using-openssl-c57f1b7dc43c


### Certificate Expiration and Revocation

When a certificate expires, the certificate has to be renewed by the service. Ideally, the service will renew the certificate before it expires. Signatures can also be manually **revoked** by the CA before the expiration date if such circumstances include change of name, change of association between subject and CA (e.g., an employee terminates employment with an organization), and compromise or suspected compromise of the corresponding private key.

Traditionally, this is done through a **Certificate Revocation List (CRL)**. 
This is a list, stored on disk, of certificates that have been revoked by a CA. These lists have to be re-downloaded periodically in order to know which certificates have recently been revoked.

CRL (Certificate Revocation List), RFC5280, is a non-interactive protocol. https://datatracker.ietf.org/doc/html/rfc5280

Test Data


Steps to create CRL
* generate CA key:
openssl genrsa -out ca.key 4096
* create self-signed root CA
openssl req -new -x509 -days 1826 -key ca.key -out ca.crt
* private key for your certificate
openssl genrsa -out cert.key 4096
* make certificate request
openssl req -new -key cert.key -out cert.csr
* create index
touch certindex
echo 01 > certserial
echo 01 > crlnumber
* create ca.conf and paste the following. Replace "test.com" with your desired certificate Common Name
See ca.conf
* Sign your request
openssl ca -batch -config ca.conf -notext -in cert.csr -out cert.crt
* Export to a PKCS12 format:
openssl pkcs12 -export -out cert.p12 -inkey cert.key -in cert.crt -chain -CAfile ca.crt
* Create the CRL file
openssl ca -config ca.conf -gencrl -keyfile ca.key -cert ca.crt -out rt.crl.pem
openssl crl -inform PEM -in rt.crl.pem -outform DER -out root.crl
rm rt.crl.pem
* Convert the CRL file to PEM format:
openssl crl -in root.crl -inform DER -out crl.pem






