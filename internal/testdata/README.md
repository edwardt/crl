Test Data Generation

https://medium.com/@arpanagupta10/understanding-certificate-revocation-list-using-openssl-c57f1b7dc43c


### Certificate Expiration and Revocation

When a certificate expires, the certificate has to be renewed by the service. Ideally, the service will renew the certificate before it expires. Signatures can also be manually **revoked** by the CA before the expiration date if such circumstances include change of name, change of association between subject and CA (e.g., an employee terminates employment with an organization), and compromise or suspected compromise of the corresponding private key.

Traditionally, this is done through a **Certificate Revocation List (CRL)**. 
This is a list, stored on disk, of certificates that have been revoked by a CA. These lists have to be re-downloaded periodically in order to know which certificates have recently been revoked.

CRL (Certificate Revocation List), RFC5280, is a non-interactive protocol. https://datatracker.ietf.org/doc/html/rfc5280

Test Data


Steps to create CRL


